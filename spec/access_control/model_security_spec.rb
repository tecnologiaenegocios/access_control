require 'spec_helper'

module AccessControl
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

    after do
      model_klass
      Object.send(:remove_const, 'Record')
    end

    describe ModelSecurity::ClassMethods do

      describe "protection of methods" do

        let(:test_object) do
          object = Class.new
          object.extend(ModelSecurity::ClassMethods)
          object
        end

        before do
          test_object.permissions_for_methods.delete(:some_method)
        end

        it "is managed through #protect" do
          test_object.protect(:some_method, :with => 'some permission')
          test_object.permissions_for(:some_method).should == Set.new([
            'some permission'
          ])
        end

        it "always combines permissions" do
          test_object.protect(:some_method, :with => 'some permission')
          test_object.protect(:some_method, :with => 'some other permission')
          test_object.permissions_for(:some_method).should == Set.new([
            'some permission', 'some other permission'
          ])
        end

        it "accepts an array of permissions" do
          test_object.protect(:some_method,
                              :with => ['some permission', 'some other'])
          test_object.permissions_for(:some_method).should == Set.new([
            'some permission', 'some other'
          ])
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

          it "complains if a has_many :as is passed" do
            model_klass.class_eval do
              belongs_to :foo
              has_many :parents, :as => :fooables
            end
            lambda {
              model_klass.inherits_permissions_from(:foo, :parents)
            }.should raise_exception(AccessControl::InvalidInheritage)
          end

          it "complains if a has_one :as is passed" do
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
              has_many :child_objects
              has_one :one_child_object
              has_and_belongs_to_many :other_child_objects
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
            has_many :parent_assoc, :class_name => self.name
            inherits_permissions_from :parent_assoc
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

      end

      describe "child node list" do

        before do
          model_klass.send(:include, ModelSecurity::InstanceMethods)
        end

        it "is empty by default" do
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
          ::AccessControl::Model::Node.create_global_node!
        end

        it "creates a node when the instance is created" do
          record = model_klass.new
          record.save!
          ::AccessControl::Model::Node.
            find_all_by_securable_type_and_securable_id(
              record.class.name, record.id
            ).size.should == 1
        end

        it "creates one node with the parents' nodes" do
          parent_node1 = stub('parent node1')
          parent_node2 = stub('parent node2')
          parent1 = stub('parent1', :ac_node => parent_node1)
          parent2 = stub('parent2', :ac_node => parent_node2)
          record = model_klass.new
          record.stub!(:parents).and_return([parent1, parent2])
          ::AccessControl::Model::Node.should_receive(:create!).
            with(:securable => record, :parents => [parent_node1, parent_node2])
          record.save
        end

        it "doesn't create any node if the object is not securable" do
          record = model_klass.new
          record.stub!(:parents).and_return([])
          model_klass.stub!(:securable?).and_return(false)
          ::AccessControl::Model::Node.should_not_receive(:create!)
          record.save
        end

        it "creates the node using a saved instance" do
          # The reason for this is that if the instance is not saved yet,
          # AccessControl::Model::Node will try to save it before being saved
          # itself, which may lead to infinite recursion.
          record = model_klass.new
          record.stub!(:parents).and_return([])
          ::AccessControl::Model::Node.stub!(:create!) do |hash|
            hash[:securable].should_not be_new_record
          end
          record.save
        end

      end

      describe "on update" do

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
          end
        end

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

        let(:global_node) { ::AccessControl::Model::Node.global }

        before do
          ::AccessControl::Model::Node.create_global_node!
        end

        it "updates parents of the node" do
          model_klass.class_eval do
            inherits_permissions_from :records
          end
          record = model_klass.create!(:records => [parent1, parent2])
          record.records = [parent3, parent4]
          record.save!
          node = record.ac_node
          node.ancestors.should include(node)
          node.ancestors.should include(parent_node3)
          node.ancestors.should include(parent_node4)
          node.ancestors.should include(global_node)
          node.ancestors.size.should == 4
        end

        it "updates child's parents when it is a belongs_to" do
          model_klass.class_eval do
            propagates_permissions_to :record, :records_records
          end
          record = model_klass.create!(
            :record => child1,
            :records_records => [child2]
          )
          record.record = child3
          Record.should_receive(:find).with(child1.id).and_return(child1)
          child1.should_receive(:update_parent_nodes)
          child3.should_receive(:update_parent_nodes)
          record.save!
        end

        it "updates added children of the node" do
          model_klass.class_eval do
            propagates_permissions_to :record, :records_records
          end
          record = model_klass.create!(
            :record => child1,
            :records_records => [child2]
          )
          record.records_records << child3
          child3.should_receive(:update_parent_nodes)
          record.save
        end

        it "updates removed children of the node" do
          model_klass.class_eval do
            propagates_permissions_to :record, :records_records
          end
          record = model_klass.create!(
            :record => child1,
            :records_records => [child2, child3]
          )
          child2.should_receive(:update_parent_nodes)
          record.records_records.delete(child2)
        end

      end

      describe "when destroying a record" do
        it "destroys the ac_node" do
          AccessControl::Model::Node.create_global_node!
          record = model_klass.new
          record.save!
          record.destroy
          AccessControl::Model::Node.
            find_all_by_securable_type_and_securable_id(
              record.class.name, record.id
            ).size.should == 0
        end
      end

    end

    # These permissions are the permissions applied to restricted queries (see
    # in query interface).

    { "view permissions" => 'view',
      "query permissions" => 'query'}.each do |k, v|

      describe k do

        it "can be defined in class level" do
          model_klass.send("#{v}_permissions=", 'some permission')
        end

        it "can be queried in class level (returns an array)" do
          model_klass.send("#{v}_permissions=", 'some permission')
          model_klass.send("#{v}_permissions").should == ['some permission']
        end

        it "defaults to config's value if it is already an array" do
          AccessControl.config.send(
            "default_#{v}_permissions=",
            ['some permission']
          )
          model_klass.send("#{v}_permissions").should == ['some permission']
        end

        it "defaults to config's value if it is a string, returns an array" do
          AccessControl.config.send(
            "default_#{v}_permissions=",
            'some permission'
          )
          model_klass.send("#{v}_permissions").should == ['some permission']
        end

        it "defaults to config's value even if it changes between calls" do
          AccessControl.config.send(
            "default_#{v}_permissions=",
            ['some permission']
          )
          model_klass.send("#{v}_permissions").should == ['some permission']
          AccessControl.config.send(
            "default_#{v}_permissions=",
            ['another permission']
          )
          model_klass.send("#{v}_permissions").should == ['another permission']
        end

        it "doesn't mess with the config's value" do
          AccessControl.config.send(
            "default_#{v}_permissions=",
            ['some permission']
          )
          model_klass.send("#{v}_permissions=", 'another permission')
          AccessControl.config.send("default_#{v}_permissions").
            should == ['some permission']
        end

      end

      describe "additional #{k}" do

        it "is empty by default" do
          model_klass.send("additional_#{v}_permissions").should be_empty
        end

        it "can be defined in class level" do
          model_klass.send("additional_#{v}_permissions=", 'some permission')
        end

        it "can be queried in class level (returns an array)" do
          model_klass.send("additional_#{v}_permissions=", 'some permission')
          model_klass.send("additional_#{v}_permissions").
            should == ['some permission']
        end

        it "can have a string appended (seen by ##{v}_permissions)" do
          AccessControl.config.send(
            "default_#{v}_permissions=",
            ['some permission']
          )
          model_klass.
            send("additional_#{v}_permissions") << 'another permission'
          model_klass.send("#{v}_permissions").should == ['some permission',
                                                          'another permission']
        end

        it "doesn't mess with the config's value when we push a new string" do
          AccessControl.config.send(
            "default_#{v}_permissions=",
            ['some permission']
          )
          model_klass.
            send("additional_#{v}_permissions") << 'another permission'
          AccessControl.config.send("default_#{v}_permissions").
            should == ['some permission']
        end

        it "cannot set additional permissions if ##{v}_permissions was set" do
          model_klass.send("#{v}_permissions=", 'some permission')
          model_klass.send("additional_#{v}_permissions=",
                           'another permission')
          model_klass.send("#{v}_permissions").should == ['some permission']
        end

      end

    end

    describe "query interface" do

      let(:principal) { Model::Principal.create!(:subject_type => 'User',
                                                 :subject_id => 1) }
      let(:querier_role) { Model::Role.create!(:name => 'Querier') }
      let(:simple_role) { Model::Role.create!(:name => 'Simple') }
      let(:manager) { SecurityManager.new('a controller') }

      before do
        Model::Node.create_global_node!
        Model::SecurityPolicyItem.create!(:permission_name => 'query',
                                          :role_id => querier_role.id)
        AccessControl.stub!(:get_security_manager).and_return(manager)
        manager.stub!(:principal_ids).and_return([principal.id])
        model_klass.query_permissions = 'query'
        model_klass.view_permissions = 'view'
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
          model_klass.class_eval do
            validates_uniqueness_of :field
          end

          # Create a record on which the user has no permission to access.
          record1 = model_klass.create!(:field => 1)

          # Create another record with invalid (taken) value for field.
          record2 = model_klass.new(:field => 1)

          record2.should have(1).error_on(:field)
        end

        describe "fields selection" do

          it "accepts :select => '*'" do
            record1 = model_klass.create!(:name => 'any name')
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            record2 = model_klass.create!
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
            result = model_klass.find(:all, :select => 'DISTINCT name, field')
            result.size.should == 1
            result.first.name.should == 'same name'
            result.first.field.should == 1
          end

          it "doesn't return duplicated records" do
            Model::Node.global.assignments.create!(:principal => principal,
                                                  :role => querier_role)
            record1 = model_klass.create!(:name => 'any name')
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            model_klass.find(:all).size.should == 1
          end

        end

        it "doesn't return readonly records by default" do
          record1 = model_klass.create!
          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)
          model_klass.find(:all).first.readonly?.should be_false
        end

        it "returns readonly records if :readonly => true" do
          record1 = model_klass.create!
          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => querier_role)
          model_klass.find(:all, :readonly => true).first.readonly?.
            should be_true
        end

        describe "with multiple query permissions" do

          let(:viewer_role) { Model::Role.create!(:name => 'Viewer') }
          let(:manager_role) { Model::Role.create!(:name => 'Manager') }

          before do
            model_klass.query_permissions = ['view', 'query']
            Model::SecurityPolicyItem.create!(:permission_name => 'view',
                                              :role_id => viewer_role.id)
            Model::SecurityPolicyItem.create!(:permission_name => 'view',
                                              :role_id => manager_role.id)
            Model::SecurityPolicyItem.create!(:permission_name => 'query',
                                              :role_id => manager_role.id)
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
            model_klass.find(:all).should == [record1]
          end

          it "checks multiple permissions in different nodes" do
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            Model::Node.global.assignments.create!(:principal => principal,
                                                   :role => viewer_role)
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            model_klass.find(:all).should == [record1]
          end

          it "checks multiple permissions for different principals in the "\
             "same node" do
            other_principal = Model::Principal.create!(
              :subject_type => 'Group', :subject_id => 1
            )
            manager.stub!(:principal_ids).and_return([principal.id,
                                                      other_principal.id])
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            record1.ac_node.assignments.create!(:principal => other_principal,
                                                :role => viewer_role)
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            model_klass.find(:all).should == [record1]
          end

          it "checks multiple permissions for different principals in "\
             "different nodes" do
            other_principal = Model::Principal.create!(
              :subject_type => 'Group', :subject_id => 1
            )
            manager.stub!(:principal_ids).and_return([principal.id,
                                                      other_principal.id])
            record1 = model_klass.create!
            record2 = model_klass.create!
            record3 = model_klass.create!

            Model::Node.global.assignments.create!(:principal => principal,
                                                   :role => viewer_role)
            record1.ac_node.assignments.create!(:principal => other_principal,
                                                :role => querier_role)
            model_klass.find(:all).should == [record1]
          end

        end

        describe "#find with :permissions option" do

          it "complains if :permissions is not an array" do
            lambda {
              model_klass.find(:all, :permissions => 'not an array')
            }.should raise_exception(ArgumentError)
          end

          it "checks explicitly the permissions passed in :permissions" do
            manager_role = Model::Role.create!(:name => 'Manager')
            Model::SecurityPolicyItem.create!(:permission_name => 'view',
                                              :role_id => manager_role.id)
            Model::SecurityPolicyItem.create!(:permission_name => 'query',
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
            model_klass.find(
              :all,
              :permissions => ['view', 'query']
            ).should == [record3]
          end

        end

        describe "#find with permission loading" do

          it "loads all permissions when :load_permissions is true" do
            Model::SecurityPolicyItem.create!(:permission_name => 'view',
                                              :role_id => querier_role.id)
            record1 = model_klass.create!
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            found = model_klass.find(:first, :load_permissions => true)
            model_klass.should_not_receive(:find) # Do not hit the database
                                                  # anymore.
            Model::Node.should_not_receive(:find)
            Model::Assignment.should_not_receive(:find)
            Model::Role.should_not_receive(:find)
            Model::SecurityPolicyItem.should_not_receive(:find)
            permissions = found.ac_node.ancestors.
              map(&:principal_assignments).flatten.
              map(&:role).
              map(&:security_policy_items).flatten.
              map(&:permission_name)
            permissions.size.should == 2
            permissions.should include('view')
            permissions.should include('query')
          end

          it "loads all permissions even if query restriction is disabled" do
            manager.stub!(:restrict_queries?).and_return(false)
            Model::SecurityPolicyItem.create!(:permission_name => 'view',
                                              :role_id => querier_role.id)
            record1 = model_klass.create!
            record1.ac_node.assignments.create!(:principal => principal,
                                                :role => querier_role)
            found = model_klass.find(:first, :load_permissions => true)
            model_klass.should_not_receive(:find) # Do not hit the database
                                                  # anymore.
            Model::Node.should_not_receive(:find)
            Model::Assignment.should_not_receive(:find)
            Model::Role.should_not_receive(:find)
            Model::SecurityPolicyItem.should_not_receive(:find)
            permissions = found.ac_node.ancestors.
              map(&:principal_assignments).flatten.
              map(&:role).
              map(&:security_policy_items).flatten.
              map(&:permission_name).uniq
            permissions.size.should == 2
            permissions.should include('view')
            permissions.should include('query')
          end

        end

        describe "#find_one" do

          let(:viewer_role) { Model::Role.create!(:name => 'Viewer') }

          before do
            Model::SecurityPolicyItem.create!(:permission_name => 'view',
                                              :role_id => viewer_role.id)
          end

          it "requires view permission and query permission" do
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

            lambda {
              model_klass.find(record1.id)
            }.should raise_exception

            lambda {
              model_klass.find(record2.id)
            }.should raise_exception

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

            model_klass.find(record1.id,
                             :permissions => ['view']).should == record1
            model_klass.find(record2.id,
                             :permissions => ['query']).should == record2
            model_klass.find(record3.id).should == record3
          end

          it "raises Unauthorized if the record exists but the user has no "\
             "permission" do
            record1 = model_klass.create!
            lambda {
              model_klass.find(record1.id)
            }.should raise_exception(AccessControl::Unauthorized)
          end

          it "raises RecordNotFound if the record doesn't exists" do
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
          record1 = model_klass.create!(:field => 1)
          model_klass.unrestricted_find(:all).should == [record1]
        end

      end

    end

  end
end
