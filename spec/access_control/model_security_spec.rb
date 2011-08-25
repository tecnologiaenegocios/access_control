require 'spec_helper'
require 'access_control/model_security'
require 'access_control/association_security'

module AccessControl

  describe AccessControl do
    it "is in strict mode by default" do
      AccessControl.should be_model_security_strict
    end
  end

  describe ModelSecurity do

    let(:model_klass) do
      class Object::Record < ActiveRecord::Base
        set_table_name 'records'
        def self.name
          'Record'
        end
      end
      Object::Record
    end

    let(:manager) { SecurityManager.new }

    before do
      AccessControl.configure do |config|
        config.default_query_permissions = []
        config.default_view_permissions = []
        config.default_create_permissions = []
        config.default_update_permissions = []
        config.default_destroy_permissions = []
        config.default_roles_on_create = nil
      end
      AccessControl.stub(:security_manager => manager)
      AccessControl.stub(:model_security_strict? => false)
      Principal.create_anonymous_principal!
    end

    after do
      model_klass
      Object.send(:remove_const, 'Record')
    end

    describe ModelSecurity::ClassMethods do

      describe "allocation of securable class with security manager" do
        it "performs checking of inheritance with `new`" do
          model_klass.should_receive(:check_inheritance!)
          model_klass.new
        end
        it "performs checking of inheritance with `find`" do
          AccessControl::Node.create_global_node!
          model_klass.create!
          model_klass.should_receive(:check_inheritance!)
          model_klass.unrestricted_find(:first)
        end
      end

      describe "allocation of unsecurable class" do
        before { model_klass.stub!(:securable?).and_return(false) }
        it "performs checking of inheritance with `new`" do
          model_klass.should_not_receive(:check_inheritance!)
          model_klass.new
        end
        it "performs checking of inheritance with `find`" do
          AccessControl::Node.create_global_node!
          model_klass.create!
          model_klass.should_not_receive(:check_inheritance!)
          model_klass.unrestricted_find(:first)
        end
      end

      describe "protection of belongs_to associations" do

        it "restricts the querying of an association" do
          model_klass.class_eval do
            belongs_to :record
            restrict_association :record
          end
          model_klass.association_restricted?(:record).should be_true
        end

        it "restricts the querying of an association based on system-wide "\
           "configuration option" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = true
          end
          model_klass.class_eval do
            belongs_to :record
          end
          model_klass.association_restricted?(:record).should be_true
        end

        it "allows querying if the system-wide config allows and nothing "\
           "is explicitly defined" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = false
          end
          model_klass.class_eval do
            belongs_to :record
          end
          model_klass.association_restricted?(:record).should be_false
        end

        it "can override the config option to restrict queries" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = false
          end
          model_klass.class_eval do
            belongs_to :record
            restrict_association :record
          end
          model_klass.association_restricted?(:record).should be_true
        end

        it "can override the config option to allow queries" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = true
          end
          model_klass.class_eval do
            belongs_to :record
            unrestrict_association :record
          end
          model_klass.association_restricted?(:record).should be_false
        end

        it "can restrict all associations at once" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = false
          end
          model_klass.class_eval do
            belongs_to :record
            belongs_to :another_record
            restrict_all_associations!
          end
          model_klass.association_restricted?(:record).should be_true
          model_klass.association_restricted?(:another_record).should be_true
        end

        it "can unrestrict all associations at once" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = true
          end
          model_klass.class_eval do
            belongs_to :record
            belongs_to :another_record
            unrestrict_all_associations!
          end
          model_klass.association_restricted?(:record).should be_false
          model_klass.association_restricted?(:another_record).
            should be_false
        end

      end

      describe "#parents_for_creation" do

        let(:parent1) { model_klass.create! }
        let(:parent2) { model_klass.create! }

        before do
          AccessControl::Node.create_global_node!
        end

        it "returns the global record instance if #parents is empty" do
          instance = model_klass.new
          instance.stub(:parents).and_return([])
          instance.parents_for_creation.
            should == [AccessControl::GlobalRecord.instance]
        end

        it "verifies permissions using parents if this isn't empty" do
          model_klass.class_eval(<<-eos)
            def parents
              self.class.unrestricted_find([#{parent1.id}, #{parent2.id}])
            end
          eos
          model_klass.new.parents_for_creation.should == [parent1, parent2]
        end

      end

      describe "instantiation protection" do

        before do
          model_klass.set_temporary_instantiation_requirement(
            'some context',
            'some permission'
          )
        end

        it "checks permissions when a record is instantiated" do
          manager.should_receive(:verify_access!).
            with('some context', 'some permission')
          lambda { model_klass.new }.should_not raise_exception
        end

        it "raises exception when the user cannot instantiate" do
          manager.should_receive(:verify_access!).
            with('some context', 'some permission').
            and_raise('the unauthorized exception')
          lambda {
            model_klass.new
          }.should raise_exception('the unauthorized exception')
        end

        it "doesn't verify permissions more than once" do
          manager.should_receive(:verify_access!).once.
            with('some context', 'some permission').
            and_raise('the unauthorized exception')
          lambda {
            model_klass.new
          }.should raise_exception('the unauthorized exception')
          lambda { model_klass.new }.should_not raise_exception
        end

        it "doesn't work for subclasses" do
          subclass = Class.new(model_klass)
          manager.should_not_receive(:verify_access!)
          lambda { subclass.new }.should_not raise_exception
        end

        it "doesn't mess with other models" do
          other_klass = Class.new(ActiveRecord::Base)
          manager.should_not_receive(:verify_access!)
          lambda {
            other_klass.new
          }.should_not raise_exception('the unauthorized exception')
        end

        it "can drop all temporary instantiation requirements" do
          ActiveRecord::Base.drop_all_temporary_instantiation_requirements!
          lambda { model_klass.new }.should_not raise_exception
        end

      end

      describe "create protection" do

        let(:parent1) do
          model_klass.create!
        end

        let(:parent2) do
          model_klass.create!
        end

        before do
          AccessControl::Node.create_global_node!
          parent1; parent2 # Create the nodes before setting protection
          model_klass.stub!(:permissions_required_to_create).
            and_return(Set.new(['permission']))
          model_klass.class_eval(<<-eos)
            def parents
              self.class.unrestricted_find([#{parent1.id}, #{parent2.id}])
            end
          eos
        end

        it "checks permissions in each parent node when the record is saved" do

          # Any record, in order to be added below a parent, must have the
          # required create permission in each parent involved individually.  A
          # record cannot be added below a parent without the create
          # permission.  Since we're expecting that verify_access! must be
          # called, thus we're specifing that if some of the parents doesn't
          # provide the required permission through inheritance Unauthorized
          # will be raised.

          manager.should_receive(:verify_access!).
            with(parent1.ac_node, Set.new(['permission']))
          manager.should_receive(:verify_access!).
            with(parent2.ac_node, Set.new(['permission']))

          model_klass.create!(:field => 1)
        end

        it "checks permission in the global node if there are no parents" do

          # If the record has no parents it is a root record.  But at the
          # creation time, the record has no ancestors (which would be in such
          # case the node of the record itself and the global node).  So, to
          # proper verify permissions, the checking must be done against the
          # global node.

          model_klass.class_eval do
            def parents
              []
            end
          end

          manager.should_receive(:verify_access!).
            with(Node.global, Set.new(['permission']))

          model_klass.create!(:field => 1)
        end

        it "doesn't check permission if the record was already saved" do
          manager.should_not_receive(:verify_access!)
          object = model_klass.unrestricted_find(:first)
          object.field = 1
          object.save!
        end

        describe "when the user has the required permission(s)" do
          it "creates the record" do
            manager.stub!(:verify_access!)
            model_klass.create!
            # Two parents and the record
            model_klass.unrestricted_find(:all).size.should == 3
          end
        end

        describe "when the user hasn't the required permission(s)" do
          it "doesn't create the record if Unauthorized was raised" do
            manager.should_receive(:verify_access!).with(any_args).
              and_raise(AccessControl::Unauthorized)
            lambda {
              model_klass.create!
            }.should raise_exception(AccessControl::Unauthorized)
            # Only two parents
            model_klass.unrestricted_find(:all).size.should == 2
          end
        end

      end

      describe "update protection" do

        before do
          model_klass.stub!(:permissions_required_to_update).
            and_return(Set.new(['permission']))
          AccessControl::Node.create_global_node!
          model_klass.create!(:field => 0)
        end

        it "checks permissions when the record is saved" do
          object = model_klass.unrestricted_find(:first)
          manager.should_receive(:verify_access!).
            with(object.ac_node, Set.new(['permission']))
          object.field = 1
          object.save!
        end

        describe "when the user has the required permission(s)" do
          it "saves the record" do
            object = model_klass.unrestricted_find(:first)
            manager.should_receive(:verify_access!).
              with(object.ac_node, Set.new(['permission']))
            object.field = 1
            object.save!
            model_klass.unrestricted_find(:first).field.should == 1
          end
        end

        describe "when the user hasn't the required permission(s)" do
          it "doesn't save the record if Unauthorized was raised" do
            object = model_klass.unrestricted_find(:first)
            manager.should_receive(:verify_access!).
              with(object.ac_node, Set.new(['permission'])).
              and_raise(AccessControl::Unauthorized)
            object.field = 1
            lambda {
              object.save!
            }.should raise_exception(AccessControl::Unauthorized)
            model_klass.unrestricted_find(:first).field.should == 0
          end
        end

      end

      describe "destroy protection" do

        let(:object) { model_klass.create!(:field => 0) }

        before do
          model_klass.stub!(:permissions_required_to_destroy).
            and_return(Set.new(['permission']))
          AccessControl::Node.create_global_node!
          # Create the object and cache it before any expectation.
          object
        end

        it "checks permissions when the record is destroyed" do
          manager.should_receive(:verify_access!).
            with(object.ac_node, Set.new(['permission']))
          object.destroy
        end

        it "performs the checking before the node gets destroyed" do
          # If the node is destroyed before the checking it will always fail.
          # Records would never be destroyed.
          manager.stub!(:verify_access!) do |*args|
            Node.find_by_securable_type_and_securable_id(
              model_klass.name, object.id
            ).should_not be_nil
          end
          object.destroy
        end

        describe "when the user has the required permission(s)" do
          it "deletes the record" do
            manager.should_receive(:verify_access!).
              with(object.ac_node, Set.new(['permission']))
            object.destroy
            lambda {
              model_klass.unrestricted_find(object.id)
            }.should raise_exception(ActiveRecord::RecordNotFound)
          end
        end

        describe "when the user hasn't the required permission(s)" do
          it "raises Unauthorized when calling #destroy" do
            manager.should_receive(:verify_access!).
              with(object.ac_node, Set.new(['permission'])).
              and_raise(AccessControl::Unauthorized)
            lambda {
              object.destroy
            }.should raise_exception(AccessControl::Unauthorized)
          end
          specify "the record is kept" do
            object.destroy rescue nil
            model_klass.unrestricted_find(object.id).should == object
          end
        end

      end

    end

    describe "node management" do

      describe "on create" do

        it "creates a node when the instance is created"

      end

      describe "on destroy" do

        it "destroys the node"

      end

    end

  end
end
