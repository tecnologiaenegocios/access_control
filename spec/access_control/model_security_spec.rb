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

    before do
      AccessControl.configure do |config|
        config.default_query_permissions = []
        config.default_view_permissions = []
        config.default_create_permissions = []
        config.default_update_permissions = []
        config.default_destroy_permissions = []
        config.default_roles_on_create = nil
      end
      AccessControl.stub(:model_security_strict? => false)
    end

    after do
      model_klass
      Object.send(:remove_const, 'Record')
    end

    describe ModelSecurity::ClassMethods do

      describe "allocation of securable class with security manager" do
        it "performs checking of inheritance with `new`" do
          AccessControl.stub!(:security_manager).and_return(
            AccessControl::SecurityManager.new('a controller')
          )
          model_klass.should_receive(:check_inheritance!)
          model_klass.new
        end
        it "performs checking of inheritance with `find`" do
          AccessControl.stub!(:security_manager).and_return(
            AccessControl::SecurityManager.new('a controller')
          )
          AccessControl::Node.create_global_node!
          model_klass.create!
          model_klass.should_receive(:check_inheritance!)
          model_klass.unrestricted_find(:first)
        end
      end

      describe "allocation of unsecurable class with security manager" do
        before { model_klass.stub!(:securable?).and_return(false) }
        it "performs checking of inheritance with `new`" do
          AccessControl.stub!(:security_manager).and_return(
            AccessControl::SecurityManager.new('a controller')
          )
          model_klass.should_not_receive(:check_inheritance!)
          model_klass.new
        end
        it "performs checking of inheritance with `find`" do
          AccessControl.stub!(:security_manager).and_return(
            AccessControl::SecurityManager.new('a controller')
          )
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
          model_klass.is_association_restricted?(:record).should be_true
        end

        it "restricts the querying of an association based on system-wide "\
           "configuration option" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = true
          end
          model_klass.class_eval do
            belongs_to :record
          end
          model_klass.is_association_restricted?(:record).should be_true
        end

        it "allows querying if the system-wide config allows and nothing "\
           "is explicitly defined" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = false
          end
          model_klass.class_eval do
            belongs_to :record
          end
          model_klass.is_association_restricted?(:record).should be_false
        end

        it "can override the config option to restrict queries" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = false
          end
          model_klass.class_eval do
            belongs_to :record
            restrict_association :record
          end
          model_klass.is_association_restricted?(:record).should be_true
        end

        it "can override the config option to allow queries" do
          AccessControl.configure do |config|
            config.restrict_belongs_to_association = true
          end
          model_klass.class_eval do
            belongs_to :record
            unrestrict_association :record
          end
          model_klass.is_association_restricted?(:record).should be_false
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
          model_klass.is_association_restricted?(:record).should be_true
          model_klass.is_association_restricted?(:another_record).should be_true
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
          model_klass.is_association_restricted?(:record).should be_false
          model_klass.is_association_restricted?(:another_record).
            should be_false
        end

      end

      describe "protection of methods" do

        before do
          model_klass.permissions_for_methods.delete(:some_method)
          PermissionRegistry.stub!(:register)
        end

        it "is managed through #protect" do
          model_klass.protect(:some_method, :with => 'some permission')
          model_klass.permissions_for(:some_method).should == Set.new([
            'some permission'
          ])
        end

        it "always combines permissions" do
          model_klass.protect(:some_method, :with => 'some permission')
          model_klass.protect(:some_method, :with => 'some other permission')
          model_klass.permissions_for(:some_method).should == Set.new([
            'some permission', 'some other permission'
          ])
        end

        it "accepts an array of permissions" do
          model_klass.protect(:some_method,
                              :with => ['some permission', 'some other'])
          model_klass.permissions_for(:some_method).should == Set.new([
            'some permission', 'some other'
          ])
        end

        it "register permissions passed" do
          PermissionRegistry.should_receive(:register).
            with('some permission',
                 :model => 'Record',
                 :method => 'some_method')
          model_klass.protect(:some_method, :with => 'some permission')
        end

        describe "on instances" do

          let(:manager) do
            AccessControl::SecurityManager.new('a controller')
          end

          before do
            AccessControl::Node.create_global_node!
          end

          describe "when there's no manager set" do
            it "doesn't check permissions" do
              model_klass.class_eval do
                protect :foo, :with => 'permission'
                def foo
                  'foo'
                end
              end
              manager.should_not_receive(:verify_access!)
              model_klass.create!
              model_klass.unrestricted_find(:first).foo.should == 'foo'
            end
          end

          describe "that are not from securable classes" do
            it "doesn't check permissions" do
              model_klass.class_eval do
                def self.securable?
                  false
                end
                protect :foo, :with => 'permission'
                def foo
                  'foo'
                end
              end
              AccessControl.stub!(:security_manager => manager)
              manager.should_not_receive(:verify_access!)
              model_klass.create!
              model_klass.unrestricted_find(:first).foo.should == 'foo'
            end
          end

          describe "in normal methods" do

            let(:node) do
              model_klass.unrestricted_find(:first).ac_node
            end

            before do
              model_klass.class_eval do
                protect :foo, :with => 'permission'
                def foo
                  'foo'
                end
              end
              model_klass.create!
              AccessControl.stub!(:security_manager => manager)
            end

            it "protects a method when it is called" do
              manager.should_receive(:verify_access!).
                with(node, Set.new(['permission']))
              model_klass.unrestricted_find(:first).foo.should == 'foo'
            end

            it "raises unauthorized if the access is not allowed" do
              manager.should_receive(:verify_access!).
                with(node, Set.new(['permission'])).
                and_raise(AccessControl::Unauthorized)
              lambda {
                model_klass.unrestricted_find(:first).foo
              }.should raise_exception(AccessControl::Unauthorized)
            end

          end

          describe "in column attributes methods" do

            let(:node) do
              model_klass.unrestricted_find(:first).ac_node
            end

            before do
              model_klass.class_eval do
                protect :field, :with => 'permission'
              end
              model_klass.create!(:field => 15)
              AccessControl.stub!(:security_manager => manager)
            end

            it "protects a method when it is called" do
              manager.should_receive(:verify_access!).
                with(node, Set.new(['permission']))
              model_klass.unrestricted_find(:first).field.should == 15
            end

            it "raises unauthorized if the access is not allowed" do
              manager.should_receive(:verify_access!).
                with(node, Set.new(['permission'])).
                and_raise(AccessControl::Unauthorized)
              lambda {
                model_klass.unrestricted_find(:first).field
              }.should raise_exception(AccessControl::Unauthorized)
            end

          end

          describe "in column attributes methods that are overwritten" do

            let(:node) do
              model_klass.unrestricted_find(:first).ac_node
            end

            before do
              model_klass.class_eval do
                protect :field, :with => 'permission'
                def field
                  self[:field] + 20
                end
              end
              model_klass.create!(:field => 15)
              AccessControl.stub!(:security_manager => manager)
            end

            it "protects a method when it is called" do
              manager.should_receive(:verify_access!).
                with(node, Set.new(['permission']))
              model_klass.unrestricted_find(:first).field.should == 35
            end

            it "raises unauthorized if the access is not allowed" do
              manager.should_receive(:verify_access!).
                with(node, Set.new(['permission'])).
                and_raise(AccessControl::Unauthorized)
              lambda {
                model_klass.unrestricted_find(:first).field
              }.should raise_exception(AccessControl::Unauthorized)
            end

          end

          describe "when the record is new" do

            let(:parent1) { model_klass.create! }
            let(:parent2) { model_klass.create! }

            before do
              model_klass.class_eval do
                protect :field, :with => 'permission'
              end
              parent1; parent2; # Create stuff before we setup the manager.
              AccessControl.stub!(:security_manager => manager)
            end

            it "verifies permissions using the global node" do
              manager.should_receive(:verify_access!).
                with([Node.global], Set.new(['permission']))
              model_klass.new(:field => 15).field.should == 15
            end

            it "verifies permissions using parents if this isn't empty" do
              model_klass.class_eval(<<-eos)
                def parents
                  self.class.unrestricted_find([#{parent1.id}, #{parent2.id}])
                end
              eos
              manager.should_receive(:verify_access!).
                with([parent1.ac_node, parent2.ac_node],
                     Set.new(['permission']))
              model_klass.new(:field => 15).field.should == 15
            end

            it "skips verification if class is not securable" do
              model_klass.class_eval do
                def self.securable?
                  false
                end
              end
              manager.should_not_receive(:verify_access!)
              object = model_klass.new(:field => 15)
              lambda { object.save! }.should_not raise_exception
            end

            it "skips verification if there's no manager" do
              AccessControl.stub!(:security_manager => nil)
              manager.should_not_receive(:verify_access!)
              object = model_klass.new(:field => 15)
              lambda { object.save! }.should_not raise_exception
            end 

            it "returns only the global node as a parent for creation" do
              model_klass.new.parents_for_creation.should == [
                AccessControlGlobalRecord.instance
              ]
            end

            it "returns the parents normally once they're set" do
              model_klass.class_eval(<<-eos)
                def parents
                  self.class.unrestricted_find([#{parent1.id}, #{parent2.id}])
                end
              eos
              parents = model_klass.new.parents
              parents_for_creation = model_klass.new.parents_for_creation
              parents_for_creation.should == parents
            end

          end

        end

      end

      describe "instantiation protection" do

        let(:manager) do
          AccessControl::SecurityManager.new('a controller')
        end

        before do
          AccessControl.stub!(:security_manager => manager)
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

        it "doesn't check permissions if there's no manager" do
          AccessControl.stub!(:security_manager => nil)
          manager.should_not_receive(:verify_access!)
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

        let(:manager) do
          AccessControl::SecurityManager.new('a controller')
        end

        let(:parent1) do
          model_klass.create!
        end

        let(:parent2) do
          model_klass.create!
        end

        before do
          AccessControl.stub!(:security_manager => manager)
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
          # proper verify permissions, the checking must be done agains the
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

        it "doesn't check permissions if there's no manager" do
          AccessControl.stub!(:security_manager => nil)
          manager.should_not_receive(:verify_access!)
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

        let(:manager) do
          AccessControl::SecurityManager.new('a controller')
        end

        before do
          model_klass.stub!(:permissions_required_to_update).
            and_return(Set.new(['permission']))
          AccessControl.stub!(:security_manager => manager)
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

        it "doesn't check permissions if there's no manager" do
          AccessControl.stub!(:security_manager => nil)
          manager.should_not_receive(:verify_access!)
          object = model_klass.unrestricted_find(:first)
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

        let(:manager) do
          AccessControl::SecurityManager.new('a controller')
        end

        before do
          model_klass.stub!(:permissions_required_to_destroy).
            and_return(Set.new(['permission']))
          AccessControl.stub!(:security_manager => manager)
          AccessControl::Node.create_global_node!
          model_klass.create!(:field => 0)
        end

        it "checks permissions when the record is destroyed" do
          object = model_klass.unrestricted_find(:first)
          manager.should_receive(:verify_access!).
            with(object.ac_node, Set.new(['permission']))
          object.destroy
        end

        it "performs the checking before the node gets destroyed" do
          # If the node is destroyed before the checking it will always fail.
          # Records would never be destroyed.
          object = model_klass.unrestricted_find(:first)
          manager.stub!(:verify_access!) do |*args|
            Node.find_by_securable_type_and_securable_id(
              model_klass.name, object.id
            ).should_not be_nil
          end
          object.destroy
        end

        it "doesn't check permissions if there's no manager" do
          AccessControl.stub!(:security_manager => nil)
          manager.should_not_receive(:verify_access!)
          object = model_klass.unrestricted_find(:first)
          object.destroy
        end

        it "doesn't check permissions if class is not securable" do
          model_klass.class_eval do
            def self.securable?
              false
            end
          end
          manager.should_not_receive(:verify_access!)
          object = model_klass.unrestricted_find(:first)
          object.destroy
        end

        describe "when the user has the required permission(s)" do
          it "deletes the record" do
            object = model_klass.unrestricted_find(:first)
            manager.should_receive(:verify_access!).
              with(object.ac_node, Set.new(['permission']))
            object.destroy
            lambda {
              model_klass.unrestricted_find(object.id)
            }.should raise_exception(ActiveRecord::RecordNotFound)
          end
        end

        describe "when the user hasn't the required permission(s)" do
          it "doesn't delete the record" do
            object = model_klass.unrestricted_find(:first)
            manager.should_receive(:verify_access!).
              with(object.ac_node, Set.new(['permission'])).
              and_raise(AccessControl::Unauthorized)
            lambda {
              object.destroy
            }.should raise_exception(AccessControl::Unauthorized)
            model_klass.unrestricted_find(object.id).should == object
          end
        end

      end

      describe "tree management" do

        describe "#inherits_permissions_from" do

          it "accepts a belongs_to association" do
            model_klass.class_eval do
              belongs_to :foo
              belongs_to :parent
            end
            model_klass.inherits_permissions_from(:foo, :parent)
            model_klass.inherits_permissions_from.should == [:foo, :parent]
          end

          it "accepts a has_many association" do
            model_klass.class_eval do
              belongs_to :foo
              has_many :parents
            end
            model_klass.inherits_permissions_from(:foo, :parents)
            model_klass.inherits_permissions_from.should == [:foo, :parents]
          end

          it "accepts a has_one association" do
            model_klass.class_eval do
              belongs_to :foo
              has_one :parent
            end
            model_klass.inherits_permissions_from(:foo, :parent)
            model_klass.inherits_permissions_from.should == [:foo, :parent]
          end

          it "accepts a has_and_belongs_to_many association" do
            model_klass.class_eval do
              belongs_to :foo
              has_and_belongs_to_many :parents
            end
            model_klass.inherits_permissions_from(:foo, :parents)
            model_klass.inherits_permissions_from.should == [:foo, :parents]
          end

          it "accepts a belongs_to with :conditions" do
            # Previously, a belongs_to was required to not have any
            # :conditions.  This was a over-constraint created to allow easy
            # construction of tree by association inspection, and :conditions
            # adds more complexity, but since a belongs_to represents a
            # straight common case and we have no support for defining
            # inheritage dinamically, we're dropping this constraint.  However,
            # if the :conditions change, the tree may be broken (there should
            # be a warning in the docs about this).
            # model_klass.class_eval do
            #   belongs_to :foo
            #   belongs_to :parent, :conditions => '1 = 2'
            # end
            # lambda {
            #   model_klass.inherits_permissions_from(:foo, :parent)
            # }.should raise_exception(AccessControl::InvalidInheritage)
            model_klass.class_eval do
              belongs_to :foo
              belongs_to :parent, :conditions => '1 = 2'
            end
            model_klass.inherits_permissions_from(:foo, :parent)
            model_klass.inherits_permissions_from.should == [:foo, :parent]
          end

          it "complains if a has_many with :conditions is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_many :parents, :conditions => '1 = 2'
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parents)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

          it "complains if a has_one with :conditions is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_one :parent, :conditions => '1 = 2'
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parent)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

          it "complains if a habtm with :conditions is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_and_belongs_to_many :parents, :conditions => '1 = 2'
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parents)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

          it "complains if a has_many with :finder_sql is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_many :parents, :finder_sql => 'foo'
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parents)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

          it "complains if a habtm with :finder_sql is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_and_belongs_to_many :parents, :finder_sql => 'foo'
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parents)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

          it "complains if a has_many :through is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_many :parents, :through => :foo
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parents)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

          it "complains if a has_one :through is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_one :parent, :through => :foo
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parent)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

          it "complains if a has_many with :as is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_many :parents, :as => :fooables
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parents)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

          it "complains if a has_one with :as is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_one :parent, :as => :fooable
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parent)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

        end

        describe "#propagates_permissions_to" do

          before do
            model_klass.class_eval do
              belongs_to :child_object
              belongs_to :other_child_object
              belongs_to :poly_child_object, :polymorphic => true
              belongs_to :child_obj_with_cond, :conditions => '1 = 2'
              has_many :child_objects
              has_one :one_child_object
              has_and_belongs_to_many :other_child_objects
              has_and_belongs_to_many :other_child_obj_with_cond,
                                      :conditions => '1 = 2'
              has_and_belongs_to_many :other_child_obj_with_cust_finder,
                                      :finder_sql => 'foo'
            end
          end

          it "is empty by default" do
            model_klass.propagates_permissions_to.should be_empty
          end

          it "accepts a belongs_to association" do
            model_klass.propagates_permissions_to(
              :child_object,
              :other_child_object
            )
            model_klass.propagates_permissions_to.should == [
              :child_object, :other_child_object
            ]
          end

          it "accepts a has_and_belongs_to_many association" do
            model_klass.propagates_permissions_to(
              :child_object,
              :other_child_objects
            )
            model_klass.propagates_permissions_to.should == [
              :child_object,
              :other_child_objects
            ]
          end

          it "complains if a belongs_to with :conditions is passed" do
            lambda {
              model_klass.propagates_permissions_to(
                :child_obj_with_cond,
                :other_child_object
              )
            }.should raise_exception(AccessControl::InvalidPropagation)
          end

          it "complains if a habtm with :conditions is passed" do
            lambda {
              model_klass.propagates_permissions_to(
                :child_object,
                :other_child_objects,
                :other_child_obj_with_cond
              )
            }.should raise_exception(AccessControl::InvalidPropagation)
          end

          it "complains if a habtm with :finder_sql is passed" do
            lambda {
              model_klass.propagates_permissions_to(
                :child_object,
                :other_child_objects,
                :other_child_obj_with_cust_finder
              )
            }.should raise_exception(AccessControl::InvalidPropagation)
          end

          it "complains if a has_many association is passed" do
            lambda {
              model_klass.propagates_permissions_to(
                :child_objects,
                :other_child_objects
              )
            }.should raise_exception(AccessControl::InvalidPropagation)
          end

          it "complains if a has_one association is passed" do
            lambda {
              model_klass.propagates_permissions_to(
                :child_object,
                :one_child_object
              )
            }.should raise_exception(AccessControl::InvalidPropagation)
          end

          it "complains if a belongs_to association is polymorphic" do
            lambda {
              model_klass.propagates_permissions_to(
                :child_object,
                :poly_child_object
              )
            }.should raise_exception(AccessControl::InvalidPropagation)
          end

        end

        describe "relationship between parents/childs (check_inheritance!)" do

          # An inherits_permissions_from with non-belongs_to association
          # requires a matching propagates_permission_to in the reflected
          # model.

          it "raises error if there's no match between bt and hm" do
            model_klass.class_eval do
              has_many :other_records,
                       :class_name => self.name,
                       :foreign_key => :record_id
              inherits_permissions_from :other_records
            end
            lambda {
              model_klass.check_inheritance!
            }.should raise_exception(AccessControl::MissingPropagation)
          end

          it "raises error if there's no match between bt and ho" do
            model_klass.class_eval do
              belongs_to :other_record,
                         :class_name => self.name,
                         :foreign_key => :record_id
              has_one :one_other_record,
                      :class_name => self.name,
                      :foreign_key => :record_id
              inherits_permissions_from :one_other_record
            end
            lambda {
              model_klass.check_inheritance!
            }.should raise_exception(AccessControl::MissingPropagation)
          end

          it "raises error if there's no match between habtm and habtm" do
            model_klass.class_eval do
              has_and_belongs_to_many :other_records,
                                      :join_table => :records_records,
                                      :class_name => self.name,
                                      :foreign_key => :from_id,
                                      :association_foreign_key => :to_id
              inherits_permissions_from :other_records
            end
            lambda {
              model_klass.check_inheritance!
            }.should raise_exception(AccessControl::MissingPropagation)
          end

          it "doesn't raise if there's a match between bt and hm" do
            model_klass.class_eval do
              belongs_to :other_record,
                         :class_name => self.name,
                         :foreign_key => :record_id
              has_many :other_records,
                       :class_name => self.name,
                       :foreign_key => :record_id
              inherits_permissions_from :other_records
              propagates_permissions_to :other_record
            end
            lambda {
              model_klass.check_inheritance!
            }.should_not raise_exception
          end

          it "doesn't raise if there's a match between bt and ho" do
            model_klass.class_eval do
              belongs_to :other_record,
                         :class_name => self.name,
                         :foreign_key => :record_id
              has_one :one_other_record,
                      :class_name => self.name,
                      :foreign_key => :record_id
              inherits_permissions_from :one_other_record
              propagates_permissions_to :other_record
            end
            lambda {
              model_klass.check_inheritance!
            }.should_not raise_exception
          end

          it "doesn't raise if there's a match between habtm and habtm" do
            model_klass.class_eval do
              has_and_belongs_to_many :other_records,
                                      :join_table => :records_records,
                                      :class_name => self.name,
                                      :foreign_key => :from_id,
                                      :association_foreign_key => :to_id
              has_and_belongs_to_many :inv_other_records,
                                      :join_table => :records_records,
                                      :class_name => self.name,
                                      :foreign_key => :to_id,
                                      :association_foreign_key => :from_id
              inherits_permissions_from :other_records
              propagates_permissions_to :inv_other_records
            end
            lambda {
              model_klass.check_inheritance!
            }.should_not raise_exception
          end

          it "doesn't look for match if inheriting permissions from bt" do
            model_klass.class_eval do
              belongs_to :record, :class_name => self.name
              inherits_permissions_from :record
            end
            lambda {
              model_klass.check_inheritance!
            }.should_not raise_exception
          end

          it "doesn't look for match if inheriting from polymorphic bt" do
            model_klass.class_eval do
              belongs_to :recordable, :polymorphic => true
              inherits_permissions_from :recordable
            end
            lambda {
              model_klass.check_inheritance!
            }.should_not raise_exception
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
      let(:manager) { SecurityManager.new('a controller') }

      before do
        Node.create_global_node!
        SecurityPolicyItem.create!(:permission => 'query',
                                   :role_id => querier_role.id)
        manager.stub!(:principal_ids).and_return([principal.id])
        model_klass.query_requires 'query'
        model_klass.view_requires 'view'
      end

      describe "#find" do

        it "returns only the records on which the principal has permissions" do
          record1 = model_klass.create!
          record2 = model_klass.create!
          record3 = model_klass.create!

          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => simple_role)

          AccessControl.stub!(:security_manager).and_return(manager)
          result = model_klass.find(:all)
          result.should include(record1)
          result.should_not include(record2)
          result.should_not include(record3)
        end

        it "checks query permission only when the manager allows" do
          manager.stub!(:restrict_queries?).and_return(false)
          record1 = model_klass.create!
          record2 = model_klass.create!
          record3 = model_klass.create!

          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => simple_role)

          AccessControl.stub!(:security_manager).and_return(manager)
          result = model_klass.find(:all)
          result.should include(record1)
          result.should include(record2)
          result.should include(record3)
        end

        it "doesn't mess with the other conditions" do
          record1 = model_klass.create!(:field => 1)
          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)
          record2 = model_klass.create!
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => simple_role)
          record3 = model_klass.create!

          AccessControl.stub!(:security_manager).and_return(manager)
          result = model_klass.find(:all, :conditions => 'field = 1')
          result.should == [record1]
        end

        it "doesn't mess with other joins" do
          record1 = model_klass.create!(:field => 1)
          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)
          record2 = model_klass.create!
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => simple_role)
          record3 = model_klass.create!

          AccessControl.stub!(:security_manager).and_return(manager)

          # We join more records asking for records that has a complementary
          # record in the same table but with opposite signal, which will
          # result in no records.
          result = model_klass.find(
            :all,
            :conditions => 'records.field = 1',
            :joins => "
              inner join records more_records on records.id = - more_records.id
            "
          )
          result.should be_empty
        end

        it "doesn't make permission checking during validation" do
          AccessControl.stub!(:security_manager).and_return(manager)

          model_klass.class_eval do
            validates_uniqueness_of :field
          end

          # Create a record on which the user has no permission to access.
          record1 = model_klass.create!(:field => 1)

          # Create another record with invalid (taken) value for field.
          record2 = model_klass.new(:field => 1)

          record2.should have(1).error_on(:field)
        end

        it "really doesn't make permission checking during validation" do
          # This spec reinforces the above one.  Due to a flaw in our previous
          # implementation, validations could suffer from permission checking
          # if, for instance, an association was called during the validation
          # (associations disable query restriction when called to fetch the
          # record, and re-enable right after that, which cause validations to
          # get restricted).

          AccessControl.stub!(:security_manager).and_return(manager)

          model_klass.class_eval do
            belongs_to :record
            validate :my_validation_method
            validates_uniqueness_of :field
            validate :my_validation_method
            def my_validation_method
              # Make the association re-enable query restriction
              self.record_id = 1
              record
            end
          end

          # Create a record on which the user has no permission to access.
          record1 = model_klass.create!(:field => 1)

          # Create another record with invalid (taken) value for field.
          record2 = model_klass.new(:field => 1)

          record2.should have(1).error_on(:field)
        end

        it "doesn't return readonly records by default" do
          record1 = model_klass.create!
          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)

          AccessControl.stub!(:security_manager).and_return(manager)
          model_klass.find(:all).first.readonly?.should be_false
        end

        it "returns readonly records if :readonly => true" do
          record1 = model_klass.create!
          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)

          AccessControl.stub!(:security_manager).and_return(manager)
          model_klass.find(:all, :readonly => true).first.readonly?.
            should be_true
        end

        describe "fields selection" do

          it "accepts :select => '*'" do
            record1 = model_klass.create!(:name => 'any name')
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            record2 = model_klass.create!

            AccessControl.stub!(:security_manager).and_return(manager)
            model_klass.find(:all, :select => '*').first.id.should == record1.id
            model_klass.find(:all, :select => '*').first.name.should == \
              record1.name
          end

          it "accepts :select => 'DISTINCT *'" do
            record1 = model_klass.create!(:name => 'same name', :field => 1)
            record2 = model_klass.create!(:name => 'same name', :field => 1)
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            record2.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)

            AccessControl.stub!(:security_manager).and_return(manager)
            result = model_klass.find(:all, :select => 'DISTINCT *')
            result.size.should == 2
            result.first.name.should == 'same name'
            result.first.field.should == 1
            result.second.name.should == 'same name'
            result.second.field.should == 1
          end

          it "accepts :select => 'field'" do
            record1 = model_klass.create!(:field => 1)
            record2 = model_klass.create!(:field => 2)
            record3 = model_klass.create!(:field => 2)
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            record2.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            record3.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)

            AccessControl.stub!(:security_manager).and_return(manager)
            result = model_klass.find(:all, :select => 'field')
            result.size.should == 3
            result.map(&:field).sort.should == [1, 2, 2]
          end

          it "accepts :select => 'DISTINCT name, field'" do
            record1 = model_klass.create!(:name => 'same name', :field => 1)
            record2 = model_klass.create!(:name => 'same name', :field => 1)
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            record2.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)

            AccessControl.stub!(:security_manager).and_return(manager)
            result = model_klass.find(:all, :select => 'DISTINCT name, field')
            result.size.should == 1
            result.first.name.should == 'same name'
            result.first.field.should == 1
          end

          it "doesn't return duplicated records" do
            Node.global.assignments.create!(:principal => principal,
                                            :role => querier_role)
            record1 = model_klass.create!(:name => 'any name')
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            AccessControl.stub!(:security_manager).and_return(manager)
            model_klass.find(:all).size.should == 1
          end

        end

        describe "with multiple query permissions" do

          let(:viewer_role) { Role.create!(:name => 'Viewer') }
          let(:manager_role) { Role.create!(:name => 'Manager') }

          before do
            model_klass.query_requires ['view', 'query']
            SecurityPolicyItem.create!(:permission => 'view',
                                       :role_id => viewer_role.id)
            SecurityPolicyItem.create!(:permission => 'view',
                                       :role_id => manager_role.id)
            SecurityPolicyItem.create!(:permission => 'query',
                                       :role_id => manager_role.id)
            AccessControl.stub!(:security_manager).and_return(nil)
          end

          it "checks multiple permissions in the same role" do
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => manager_role)
            record2.ac_node.assignments.create!(:principal => principal,
                                                :role => viewer_role)
            record3.ac_node.assignments.create!(:principal => principal,
                                                :role => viewer_role)

            AccessControl.stub!(:security_manager).and_return(manager)
            model_klass.find(:all).should == [record1]
          end

          it "checks multiple permissions in different roles" do
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => viewer_role)
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            record2.ac_node.assignments.create!(:principal => principal,
                                                :role => viewer_role)
            record3.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)

            AccessControl.stub!(:security_manager).and_return(manager)
            model_klass.find(:all).should == [record1]
          end

          it "checks multiple permissions in different nodes" do
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            Node.global.assignments.create!(:principal => principal,
                                            :role => viewer_role)
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)

            AccessControl.stub!(:security_manager).and_return(manager)
            model_klass.find(:all).should == [record1]
          end

          it "checks multiple permissions for different principals in the "\
             "same node" do
            other_principal = Principal.create!(
              :subject_type => 'Group', :subject_id => 1
            )
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            record1.ac_node.assignments.create!(:principal => other_principal,
                                                :role => viewer_role)
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)

            manager.stub!(:principal_ids).and_return([principal.id,
                                                      other_principal.id])
            AccessControl.stub!(:security_manager).and_return(manager)
            model_klass.find(:all).should == [record1]
          end

          it "checks multiple permissions for different principals in "\
             "different nodes" do
            other_principal = Principal.create!(
              :subject_type => 'Group', :subject_id => 1
            )
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            Node.global.assignments.create!(:principal => principal,
                                            :role => viewer_role)
            record1.ac_node.assignments.create!(:principal => other_principal,
                                                :role => querier_role)

            manager.stub!(:principal_ids).and_return([principal.id,
                                                      other_principal.id])
            AccessControl.stub!(:security_manager).and_return(manager)
            model_klass.find(:all).should == [record1]
          end

        end

        describe "#find with :permissions option" do

          it "complains if :permissions is not an enumerable" do
            lambda {
              model_klass.find(:all, :permissions => 123)
            }.should raise_exception(ArgumentError)
          end

          it "checks explicitly the permissions passed in :permissions" do
            manager_role = Role.create!(:name => 'Manager')
            SecurityPolicyItem.create!(:permission => 'view',
                                       :role_id => manager_role.id)
            SecurityPolicyItem.create!(:permission => 'query',
                                       :role_id => manager_role.id)
            record1 = model_klass.create!
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            record2 = model_klass.create!
            record2.ac_node.assignments.create!(:principal => principal,
                                                :role => simple_role)
            record3 = model_klass.create!
            record3.ac_node.assignments.create!(:principal => principal,
                                                :role => manager_role)
            record4 = model_klass.create!

            AccessControl.stub!(:security_manager).and_return(manager)
            model_klass.find(:all, :permissions => ['view', 'query']).
              should == [record3]
          end

        end

        describe "#find with permission loading" do

          it "loads all permissions when :load_permissions is true" do
            SecurityPolicyItem.create!(:permission => 'view',
                                       :role_id => querier_role.id)
            record1 = model_klass.create!
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)

            AccessControl.stub!(:security_manager).and_return(manager)

            found = model_klass.find(:first, :load_permissions => true)
            model_klass.should_not_receive(:find) # Do not hit the database
                                                  # anymore.
            Node.should_not_receive(:find)
            Assignment.should_not_receive(:find)
            Role.should_not_receive(:find)
            SecurityPolicyItem.should_not_receive(:find)
            permissions = found.ac_node.ancestors.
              map(&:principal_assignments).flatten.
              map(&:role).
              map(&:security_policy_items).flatten.
              map(&:permission)
            permissions.size.should == 2
            permissions.should include('view')
            permissions.should include('query')
          end

          it "loads all permissions even if query restriction is disabled" do
            manager.stub!(:restrict_queries?).and_return(false)
            SecurityPolicyItem.create!(:permission => 'view',
                                       :role_id => querier_role.id)
            record1 = model_klass.create!
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)

            AccessControl.stub!(:security_manager).and_return(manager)

            found = model_klass.find(:first, :load_permissions => true)
            model_klass.should_not_receive(:find) # Do not hit the database
                                                  # anymore.
            Node.should_not_receive(:find)
            Assignment.should_not_receive(:find)
            Role.should_not_receive(:find)
            SecurityPolicyItem.should_not_receive(:find)
            permissions = found.ac_node.ancestors.
              map(&:principal_assignments).flatten.
              map(&:role).
              map(&:security_policy_items).flatten.
              map(&:permission).uniq
            permissions.size.should == 2
            permissions.should include('view')
            permissions.should include('query')
          end

        end

        describe "#find_one" do

          let(:viewer_role) { Role.create!(:name => 'Viewer') }

          before do
            SecurityPolicyItem.create!(:permission => 'view',
                                       :role_id => viewer_role.id)
          end

          it "requires view permission instead of query permission" do
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            record1.ac_node.assignments.create!(:principal => principal,
                                                :role_id => viewer_role.id)
            record2.ac_node.assignments.create!(:principal => principal,
                                                :role_id => querier_role.id)
            record3.ac_node.assignments.create!(:principal => principal,
                                                :role_id => viewer_role.id)
            record3.ac_node.assignments.create!(:principal => principal,
                                                :role_id => querier_role.id)

            AccessControl.stub!(:security_manager).and_return(manager)

            model_klass.find(record1.id).should == record1

            lambda { model_klass.find(record2.id) }.should raise_exception

            model_klass.find(record3.id).should == record3
          end

          it "accepts :permissions option" do
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            record1.ac_node.assignments.create!(:principal => principal,
                                                :role_id => viewer_role.id)
            record2.ac_node.assignments.create!(:principal => principal,
                                                :role_id => querier_role.id)
            record3.ac_node.assignments.create!(:principal => principal,
                                                :role_id => viewer_role.id)
            record3.ac_node.assignments.create!(:principal => principal,
                                                :role_id => querier_role.id)

            AccessControl.stub!(:security_manager).and_return(manager)

            model_klass.find(record1.id,
                             :permissions => ['view']).should == record1
            model_klass.find(record2.id,
                             :permissions => ['query']).should == record2
            model_klass.find(record3.id).should == record3
          end

          it "raises Unauthorized if the record exists but the user has no "\
             "permission" do
            AccessControl.stub!(:security_manager).and_return(manager)
            record1 = model_klass.create!
            lambda {
              model_klass.find(record1.id)
            }.should raise_exception(AccessControl::Unauthorized)
          end

          it "logs the exception if the record exists but the user has no "\
             "permission" do
            AccessControl.stub!(:security_manager).and_return(manager)
            record1 = model_klass.create!
            Util.should_receive(:log_missing_permissions).
              with(record1.ac_node, Set.new(['view']), instance_of(Array))
            lambda {
              model_klass.find(record1.id)
            }.should raise_exception(AccessControl::Unauthorized)
          end

          it "raises RecordNotFound if the record doesn't exists" do
            AccessControl.stub!(:security_manager).and_return(manager)
            record1 = model_klass.create!
            id = record1.id
            record1.destroy
            lambda {
              model_klass.find(id)
            }.should raise_exception(ActiveRecord::RecordNotFound)
          end

        end

      end

      describe "#unrestricted_find" do

        it "doesn't make permission checking" do
          AccessControl.stub!(:security_manager).and_return(manager)
          record1 = model_klass.create!(:field => 1)
          model_klass.unrestricted_find(:all).should == [record1]
        end

        it "doesn't raise NoPermissionsDeclared if there's no permissions "\
           "but queries aren't being restricted" do
          model_klass.query_requires []
          r = model_klass.create!
          AccessControl.stub(:model_security_strict? => true)
          AccessControl.config.send("default_query_permissions=", [])
          model_klass.stub(:restrict_queries? => false)
          model_klass.find(:all).should == [r]
        end

      end

      describe "#parents" do
        before do
          AccessControl.stub!(:security_manager).and_return(manager)
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
          AccessControl.stub!(:security_manager).and_return(manager)
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
