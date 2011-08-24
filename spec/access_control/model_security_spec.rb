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

        it "checks permission in the global node if there's no parents" do

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

        it "doesn't check permission if class is not securable" do
          model_klass.class_eval do
            def self.securable?
              false
            end
          end
          manager.should_not_receive(:verify_access!)
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

        it "doesn't check permissions if class is not securable" do
          model_klass.class_eval do
            def self.securable?
              false
            end
          end
          manager.should_not_receive(:verify_access!)
          object = model_klass.unrestricted_find(:first)
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

        it "doesn't check permissions if class is not securable" do
          model_klass.class_eval do
            def self.securable?
              false
            end
          end
          manager.should_not_receive(:verify_access!)
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

    describe ModelSecurity::InstanceMethods do

      it "is securable" do
        model_klass.securable?.should be_true
      end

      it "extends the class with the class methods" do
        model_klass.should_receive(:extend).with(ModelSecurity::ClassMethods)
        model_klass.send(:include, ModelSecurity::InstanceMethods)
      end

      describe "parent node list" do

        before do
          model_klass.send(:include, ModelSecurity::InstanceMethods)
        end

        it "is empty by default" do
          model_klass.new.parents.should be_empty
        end

        it "will be the parent association if defined and collection" do
          model_klass.class_eval do
            has_many :parent_assoc, :class_name => self.name,
                     :foreign_key => :record_id
            belongs_to :child_assoc, :class_name => self.name,
                       :foreign_key => :record_id
            inherits_permissions_from :parent_assoc
            propagates_permissions_to :child_assoc
            def parent_assoc
              ['some parents']
            end
          end
          model_klass.new.parents.should == ['some parents']
        end

        it "will be an array of one element if the parent assoc is single" do
          model_klass.class_eval do
            belongs_to :parent_assoc, :class_name => self.name
            inherits_permissions_from :parent_assoc
            def parent_assoc
              'some parent'
            end
          end
          model_klass.new.parents.should == ['some parent']
        end

        it "returns an empty array if tree creation is disabled" do
          config = AccessControl::Configuration.new
          config.tree_creation = false
          AccessControl.stub!(:config).and_return(config)
          model_klass.class_eval do
            belongs_to :parent_assoc, :class_name => self.name
            inherits_permissions_from :parent_assoc
            def parent_assoc
              'some parent'
            end
          end
          model_klass.new.parents.should be_empty
        end

      end

      describe "child node list" do

        before do
          model_klass.send(:include, ModelSecurity::InstanceMethods)
        end

        it "is empty by default" do
          model_klass.new.children.should be_empty
        end

        it "returns an empty array if tree creation is disabled" do
          config = AccessControl::Configuration.new
          config.tree_creation = false
          AccessControl.stub!(:config).and_return(config)
          model_klass.class_eval do
            belongs_to :test, :class_name => self.name
            def test
              'a single object'
            end
            propagates_permissions_to :test
          end
          model_klass.new.children.should be_empty
        end

        describe "when there's one child belongs_to association" do

          before do
            model_klass.class_eval do
              belongs_to :test, :class_name => self.name
              propagates_permissions_to :test
            end
          end

          it "wraps the value of the association in an array" do
            model_klass.class_eval do
              def test
                'a single object'
              end
            end
            model_klass.new.children.should == ['a single object']
          end

        end

        describe "when there's many child associations" do

          before do
            model_klass.class_eval do
              belongs_to :child1, :class_name => self.name
              belongs_to :child2, :class_name => self.name
              has_and_belongs_to_many(
                :child3,
                :class_name => self.name,
                :foreign_key => :make_rails_happy
              )
              propagates_permissions_to :child1, :child2, :child3
              def child1
                'child1'
              end
              def child2
                'child2'
              end
              def child3
                ['child1', 'child3']
              end
            end
          end

          it "returns an array containing the records of all associations" do
            model_klass.new.children.should include('child1')
            model_klass.new.children.should include('child2')
            model_klass.new.children.should include('child3')
          end

          it "returns an array with unique records" do
            model_klass.new.children.size.should == 3
          end

        end

      end

    end

    describe "node management" do

      describe "when the object is not securable" do
        it "returns nil on ac_node association" do
          record = model_klass.new
          model_klass.stub(:securable?).and_return(false)
          record.ac_node.should be_nil
        end
      end

      describe "on create" do

        before do
          ::AccessControl::Node.create_global_node!
        end

        it "creates a node when the instance is created" do
          record = model_klass.new
          record.save!
          ::AccessControl::Node.
            find_all_by_securable_type_and_securable_id(
              record.class.name, record.id
            ).size.should == 1
        end

        it "creates one node with the parents' nodes" do
          parent_node1 = stub('parent node1')
          parent_node2 = stub('parent node2')
          parent1 = stub('parent1', :ac_node => parent_node1)
          parent2 = stub('parent2', :ac_node => parent_node2)
          built_node = mock('built node')
          record = model_klass.new
          record.stub!(:parents).and_return([parent1, parent2])
          record.should_receive(:build_ac_node).
            with(:parents => [parent_node1, parent_node2]).
            and_return(built_node)
          built_node.should_receive(:save!)
          record.save
        end

        it "doesn't create any node if the object is not securable" do
          record = model_klass.new
          record.stub!(:parents).and_return([])
          model_klass.stub!(:securable?).and_return(false)
          record.should_not_receive(:build_ac_node)
          record.save
        end

        it "creates the node using a saved securable instance" do
          # The reason for this is that if the instance is not saved yet,
          # AccessControl::Node will try to save it before being saved itself,
          # which may lead to infinite recursion.
          record = model_klass.new
          record.stub!(:parents).and_return([])
          record.stub!(:build_ac_node) do |hash|
            record.instance_eval{self.new_record?.should_not == true}
            stub('built node', :save! => true)
          end
          record.save
        end

      end

      describe "" do

        before do
          model_klass.class_eval do
            belongs_to :record
            has_one :one_record, :class_name => self.name
            has_many :records
            has_and_belongs_to_many(
              :records_records,
              :class_name => self.name,
              :join_table => :records_records,
              :foreign_key => :from_id,
              :association_foreign_key => :to_id
            )
            has_and_belongs_to_many(
              :inverse_records_records,
              :class_name => self.name,
              :join_table => :records_records,
              :foreign_key => :to_id,
              :association_foreign_key => :from_id
            )
          end
        end

        let(:global_node) { ::AccessControl::Node.global }

        before do
          ::AccessControl::Node.create_global_node!
        end

        describe "on update" do

          let(:parent1) { model_klass.create! }
          let(:parent2) { model_klass.create! }
          let(:parent3) { model_klass.create! }
          let(:parent4) { model_klass.create! }

          let(:parent_node1) { parent1.ac_node }
          let(:parent_node2) { parent2.ac_node }
          let(:parent_node3) { parent3.ac_node }
          let(:parent_node4) { parent4.ac_node }

          let(:child1) { model_klass.create! }
          let(:child2) { model_klass.create! }
          let(:child3) { model_klass.create! }

          let(:child_node1) { child1.ac_node }
          let(:child_node2) { child2.ac_node }
          let(:child_node3) { child3.ac_node }

          it "updates parents of the node for :belongs_to" do
            model_klass.class_eval do
              inherits_permissions_from :record
            end
            record = model_klass.create!(:record => parent1)
            record.record = parent2
            record.save!
            node = record.ac_node
            node.ancestors.should include(node)
            node.ancestors.should include(parent_node2)
            node.ancestors.should include(global_node)
            parent_node1.descendants.should_not include(node)
            node.ancestors.size.should == 3
          end

          it "updates parents of the node for :has_many" do
            model_klass.class_eval do
              inherits_permissions_from :records
              propagates_permissions_to :record
            end
            record = model_klass.create!(:records => [parent1, parent2])
            record.records = [parent3, parent4]
            node = record.ac_node
            node.ancestors.should include(node)
            node.ancestors.should include(parent_node3)
            node.ancestors.should include(parent_node4)
            node.ancestors.should include(global_node)
            parent_node1.descendants.should_not include(node)
            parent_node2.descendants.should_not include(node)
            node.ancestors.size.should == 4
          end

          it "updates parents of the node for :has_one" do
            model_klass.class_eval do
              inherits_permissions_from :one_record
              propagates_permissions_to :record
            end
            record = model_klass.create!(:one_record => parent1)
            record.one_record = parent3
            node = record.ac_node
            node.ancestors.should include(node)
            node.ancestors.should include(parent_node3)
            node.ancestors.should include(global_node)
            parent_node1.descendants.should_not include(node)
            node.ancestors.size.should == 3
          end

          it "updates parents of the node for :habtm" do
            model_klass.class_eval do
              inherits_permissions_from :records_records
              propagates_permissions_to :inverse_records_records
            end
            record = model_klass.create!(:records_records => [parent1, parent2])
            record.records_records = [parent3, parent4]
            node = record.ac_node
            node.ancestors.should include(node)
            node.ancestors.should include(parent_node3)
            node.ancestors.should include(parent_node4)
            node.ancestors.should include(global_node)
            parent_node1.descendants.should_not include(node)
            parent_node2.descendants.should_not include(node)
            node.ancestors.size.should == 4
          end

          it "doesn't break when association was updated and then the record" do
            # The reason of this spec is that by updating the has_many
            # association (it could be a has_one or habtm) we are implicitly
            # updating the record itself behind the scenes (by making it to
            # reset its parents to the new ones given), but this should not
            # stop us to update the record explicitly if we want.  The system
            # should not complain about duplicated parents when updating the
            # record.
            model_klass.class_eval do
              inherits_permissions_from :records
              propagates_permissions_to :record
            end
            record = model_klass.create!(:records => [parent1, parent2])
            record.records = [parent3, parent4]
            record.save!
          end

          it "updates child's parents when it is a belongs_to" do
            model_klass.class_eval do
              inherits_permissions_from :records, :inverse_records_records
              propagates_permissions_to :record, :records_records
            end
            record = model_klass.create!(
              :record => child1,
              :records_records => [child2]
            )
            record.record = child3
            record.save! # `record` is a :belongs_to, so we must save explicitly
            node = record.ac_node
            node.descendants.should include(node)
            node.descendants.should_not include(child_node1)
            node.descendants.should include(child_node2)
            node.descendants.should include(child_node3)
            node.descendants.size.should == 3
          end

          it "updates added children of the node" do
            model_klass.class_eval do
              inherits_permissions_from :records, :inverse_records_records
              propagates_permissions_to :record, :records_records
            end
            record = model_klass.create!(
              :record => child1,
              :records_records => [child2]
            )
            record.records_records << child3
            node = record.ac_node
            node.descendants.should include(node)
            node.descendants.should include(child_node1)
            node.descendants.should include(child_node2)
            node.descendants.should include(child_node3)
            node.descendants.size.should == 4
          end

          it "updates removed children of the node" do
            model_klass.class_eval do
              inherits_permissions_from :records, :inverse_records_records
              propagates_permissions_to :record, :records_records
            end
            record = model_klass.create!(
              :record => child1,
              :records_records => [child2, child3]
            )
            record.records_records.delete(child2)
            node = record.ac_node
            node.descendants.should include(node)
            node.descendants.should include(child_node1)
            node.descendants.should_not include(child_node2)
            node.descendants.should include(child_node3)
            node.descendants.size.should == 3
          end

        end

        describe "when destroying a record" do

          let(:ancestor) do
            model_klass.create!
          end

          let(:parent) do
            model_klass.create!(:record => ancestor)
          end

          let(:record) do
            model_klass.create!(:record => parent)
          end

          let(:child) do
            model_klass.create!(:record => record)
          end

          let(:descendant) do
            model_klass.create!(:record => child)
          end

          describe "without re-parenting" do

            before do
              model_klass.class_eval do
                inherits_permissions_from :record
              end
              descendant # Wake up the tree.
              record.destroy
            end

            it "destroys the ac_node" do
              AccessControl::Node.
                find_all_by_securable_type_and_securable_id(
                  record.class.name, record.id
                ).size.should == 0
            end

            it "removes the node from the ascendancy of its descendants" do
              child.ac_node.ancestors.should_not include(record.ac_node)
              descendant.ac_node.ancestors.should_not include(record.ac_node)
            end

            it "removes the node from the descendancy of its ascendancy" do
              ancestor.ac_node.descendants.should_not include(record.ac_node)
              parent.ac_node.descendants.should_not include(record.ac_node)
            end

            it "makes the child a new root" do
              child.ac_node.ancestors.should include(global_node)
              child.ac_node.ancestors.should include(child.ac_node)
              child.ac_node.ancestors.size.should == 2
            end

            it "keeps the descendant above the child" do
              descendant.ac_node.ancestors.should include(global_node)
              descendant.ac_node.ancestors.should include(child.ac_node)
              descendant.ac_node.ancestors.should include(descendant.ac_node)
              descendant.ac_node.ancestors.size.should == 3
            end

          end

          describe "without re-parenting, but when dependants are destroyed" do

            before do
              model_klass.class_eval do
                inherits_permissions_from :record
                has_many :records, :dependent => :destroy
              end
              descendant # Wake up the tree.
              record.destroy
            end

            it "destroys the ac_node" do
              AccessControl::Node.
                find_all_by_securable_type_and_securable_id(
                  record.class.name, record.id
                ).size.should == 0
            end

            it "destroys descendant ac_nodes" do
              AccessControl::Node.
                find_all_by_securable_type_and_securable_id(
                  child.class.name, child.id
                ).size.should == 0
              AccessControl::Node.
                find_all_by_securable_type_and_securable_id(
                  descendant.class.name, descendant.id
                ).size.should == 0
            end

            it "removes nodes from the descendancy of its ascendancy" do
              ancestor.ac_node.descendants.should_not include(record.ac_node)
              ancestor.ac_node.descendants.should_not include(child.ac_node)
              ancestor.ac_node.descendants.should_not include(descendant.ac_node)
              parent.ac_node.descendants.should_not include(record.ac_node)
              parent.ac_node.descendants.should_not include(child.ac_node)
              parent.ac_node.descendants.should_not include(descendant.ac_node)
            end

          end

          describe "with re-parenting" do

            before do
              model_klass.class_eval do
                inherits_permissions_from :record
              end
              # The child instance is expected to know about its new parent(s)
              # (the parents to where it will be re-parented to in the tree
              # when its immediate parent -- the "record" -- is removed), and
              # for the purpose of this spec we want it to return the record's
              # parent's parent as the new parent.
              model_klass.class_eval(<<-eos)
                def parents
                  if self.id == #{child.id}
                    return self.class.find([#{ancestor.id}])
                  else
                    super
                  end
                end
              eos
              descendant # Wake up the tree.
              record.destroy
            end

            it "destroys the ac_node" do
              AccessControl::Node.
                find_all_by_securable_type_and_securable_id(
                  record.class.name, record.id
                ).size.should == 0
            end

            it "removes the node from the ascendancy of its descendants" do
              child.ac_node.ancestors.should_not include(record.ac_node)
              descendant.ac_node.ancestors.should_not include(record.ac_node)
            end

            it "removes the node from the descendancy of its ascendancy" do
              ancestor.ac_node.descendants.should_not include(record.ac_node)
              parent.ac_node.descendants.should_not include(record.ac_node)
            end

            it "re-parents the descendant nodes" do
              child.ac_node.ancestors.should include(global_node)
              child.ac_node.ancestors.should include(ancestor.ac_node)
              child.ac_node.ancestors.should include(child.ac_node)
              child.ac_node.ancestors.size.should == 3
              descendant.ac_node.ancestors.should include(global_node)
              descendant.ac_node.ancestors.should include(ancestor.ac_node)
              descendant.ac_node.ancestors.should include(child.ac_node)
              descendant.ac_node.ancestors.should include(descendant.ac_node)
              descendant.ac_node.ancestors.size.should == 4
            end

            it "\"re-childrens\" the ancestor nodes" do
              ancestor.ac_node.descendants.should include(ancestor.ac_node)
              ancestor.ac_node.descendants.should include(parent.ac_node)
              ancestor.ac_node.descendants.should include(child.ac_node)
              ancestor.ac_node.descendants.should include(descendant.ac_node)
              ancestor.ac_node.descendants.size.should == 4
              # Remember: the child node was re-parented right below the ancestor
              # record, not the parent record.
              parent.ac_node.descendants.should include(parent.ac_node)
              parent.ac_node.descendants.size.should == 1
              child.ac_node.descendants.should include(child.ac_node)
              child.ac_node.descendants.should include(descendant.ac_node)
              child.ac_node.descendants.size.should == 2
              descendant.ac_node.descendants.should include(descendant.ac_node)
              descendant.ac_node.descendants.size.should == 1
            end

          end

        end

      end

    end

    {
      "view requirement" => 'view',
      "query requirement" => 'query',
      "create requirement" => 'create',
      "update requirement" => 'update',
      "destroy requirement" => 'destroy',
    }.each do |k, v|

      describe k do

        it "can be defined in class level" do
          model_klass.send("#{v}_requires", 'some permission')
        end

        it "requires at least one permission by default" do
          AccessControl.stub(:model_security_strict? => true)
          AccessControl.config.send("default_#{v}_permissions=", [])
          lambda {
            model_klass.send("permissions_required_to_#{v}")
          }.should raise_exception(AccessControl::NoPermissionsDeclared)
        end

        it "doesn't requires any permission if :none is set" do
          AccessControl.stub(:model_security_strict? => true)
          AccessControl.config.send("default_#{v}_permissions=", [])
          model_klass.send("#{v}_requires", :none)
          model_klass.send("permissions_required_to_#{v}").should == Set.new
        end

        it "can be queried in class level (returns a set)" do
          model_klass.send("#{v}_requires", 'some permission')
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission'])
        end

        it "can accept a list of arguments" do
          model_klass.send("#{v}_requires", 'some permission',
                           'another permission')
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "can accept an enumerable as a single argument" do
          model_klass.send("#{v}_requires",
                           ['some permission', 'another permission'])
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "defaults to config's value" do
          AccessControl.config.send("default_#{v}_permissions=",
                                    ['some permission'])
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission'])
        end

        it "defaults to config's value even if it changes between calls" do
          AccessControl.config.send("default_#{v}_permissions=",
                                    ['some permission'])
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission'])
          AccessControl.config.send("default_#{v}_permissions=",
                                    ['another permission'])
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['another permission'])
        end

        it "doesn't mess with the config's value" do
          AccessControl.config.send("default_#{v}_permissions=",
                                    ['some permission'])
          model_klass.send("#{v}_requires", 'another permission')
          AccessControl.config.send("default_#{v}_permissions").
            should == Set.new(['some permission'])
        end

        it "can be inherited by subclasses" do
          subclass = Class.new(model_klass)
          model_klass.send("#{v}_requires", 'some permission')
          subclass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission'])
        end

        it "can be changed in subclasses" do
          subclass = Class.new(model_klass)
          model_klass.send("#{v}_requires", 'some permission')
          subclass.send("#{v}_requires", 'another permission')
          subclass.send("permissions_required_to_#{v}").
            should == Set.new(['another permission'])
        end

        it "informs PermissionRegistry about the permissions" do
          PermissionRegistry.should_receive(:register).
            with('some permission',
                 :model => 'Record',
                 :action => v)
          model_klass.send("#{v}_requires", 'some permission')
        end

      end

      describe "additional #{k}" do

        it "can be defined in class level" do
          model_klass.send("add_#{v}_requirement", 'some permission')
        end

        it "can be queried in class level, combines with current permissions" do
          AccessControl.config.send("default_#{v}_permissions=",
                                    ['some permission'])
          model_klass.send("add_#{v}_requirement", 'another permission')
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "can accept a list of arguments" do
          model_klass.send("add_#{v}_requirement", 'some permission',
                           'another permission')
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "can accept an enumerable as a single argument" do
          model_klass.send("add_#{v}_requirement",
                           ['some permission', 'another permission'])
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "doesn't mess with the config's value when we push a new string" do
          AccessControl.config.send("default_#{v}_permissions=",
                                    ['some permission'])
          model_klass.send("add_#{v}_requirement", 'another permission')
          AccessControl.config.send("default_#{v}_permissions").
            should == Set.new(['some permission'])
        end

        it "can set additional permissions even if ##{v}_requires was set" do
          model_klass.send("#{v}_requires", 'some permission')
          model_klass.send("add_#{v}_requirement", 'another permission')
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['some permission', 'another permission'])
        end

        it "combines permissions from superclasses" do
          subclass = Class.new(model_klass)
          model_klass.send("#{v}_requires", 'permission one')
          subclass.send("add_#{v}_requirement", 'permission two')
          subclass.send("permissions_required_to_#{v}").
            should == Set.new(['permission one', 'permission two'])
        end

        it "combines permissions from superclasses and config" do
          AccessControl.config.send("default_#{v}_permissions=",
                                    ['permission one'])
          subclass = Class.new(model_klass)
          model_klass.send("add_#{v}_requirement", 'permission two')
          subclass.send("add_#{v}_requirement", 'permission three')
          subclass.send("permissions_required_to_#{v}").
            should == Set.new(['permission one', 'permission two',
                               'permission three'])
        end

        it "doesn't mess with superclass' permissions" do
          subclass = Class.new(model_klass)
          model_klass.send("#{v}_requires", 'permission one')
          subclass.send("add_#{v}_requirement", 'permission two')
          model_klass.send("permissions_required_to_#{v}").
            should == Set.new(['permission one'])
        end

        it "informs PermissionRegistry about the permissions" do
          PermissionRegistry.should_receive(:register).
            with('some permission',
                 :model => 'Record',
                 :action => v)
          model_klass.send("add_#{v}_requirement", 'some permission')
        end

      end

    end

    describe "query interface" do

      let(:principal) { Principal.create!(:subject_type => 'User',
                                          :subject_id => 1) }
      let(:querier_role) { Role.create!(:name => 'Querier') }
      let(:simple_role) { Role.create!(:name => 'Simple') }

      before do
        Node.create_global_node!
        SecurityPolicyItem.create!(:permission => 'query',
                                   :role_id => querier_role.id)
        manager.stub!(:principal_ids).and_return([principal.id])
        manager.stub!(:can_assign_or_unassign?).and_return(true)
        model_klass.query_requires 'query'
        model_klass.view_requires 'view'
      end

      describe "#parents" do
        before do
          model_klass.class_eval do
            belongs_to :record
            inherits_permissions_from :record
          end
        end
        it "queries associations without restriction" do
          parent = model_klass.create!
          record = model_klass.create!(:record => parent)
          # Reload, but without permission checking
          record = model_klass.unrestricted_find(record.id)
          record.parents.should == [parent]
        end
        it "keeps query restriction" do
          # This ensures that the restriction of queries work after calling
          # this method.
          parent = model_klass.create!
          record = model_klass.create!(:record => parent)
          # Reload, but without permission checking
          record = model_klass.unrestricted_find(record.id)
          # Call
          record.parents
          lambda {
            record.reload
          }.should raise_exception(AccessControl::Unauthorized)
        end
      end

      describe "#children" do
        before do
          model_klass.class_eval do
            has_many :records
            belongs_to :record
            inherits_permissions_from :records
            propagates_permissions_to :record
          end
        end
        it "queries associations without restriction" do
          parent = model_klass.create!
          record = model_klass.create!(:records => [parent])
          # Reload, but without permission checking
          parent = model_klass.unrestricted_find(parent.id)
          parent.children.should == [record]
        end
        it "keeps query restriction" do
          # This ensures that the restriction of queries work after calling
          # this method.
          parent = model_klass.create!
          record = model_klass.create!(:records => [parent])
          # Reload, but without permission checking
          parent = model_klass.unrestricted_find(parent.id)
          # Call
          parent.children
          lambda {
            parent.reload
          }.should raise_exception(AccessControl::Unauthorized)
        end
      end

    end

  end
end
