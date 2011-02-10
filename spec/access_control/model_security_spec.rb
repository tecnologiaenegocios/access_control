require 'spec_helper'

module AccessControl
  describe ModelSecurity do

    let(:model_klass) do
      klass = Class.new(ActiveRecord::Base)
      klass.class_eval do
        set_table_name 'records'
        def self.name
          'Record'
        end
      end
      klass
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

      describe "parent association" do

        let(:test_object) do
          object = Class.new
          object.extend(ModelSecurity::ClassMethods)
          object
        end

        it "can be defined" do
          test_object.parent_association(:test)
          test_object.parent_association.should == :test
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
            parent_association :parent_assoc
            def parent_assoc
              ['some parents']
            end
          end
          model_klass.new.parents.should == ['some parents']
        end

        it "will be an array of one element if the parent assoc is single" do
          model_klass.class_eval do
            parent_association :parent_assoc
            def parent_assoc
              'some parent'
            end
          end
          model_klass.new.parents.should == ['some parent']
        end

      end

    end

    describe "node management" do

      describe "on first access to ac_node" do

        it "creates one node with the parent's nodes if not new record" do
          parent_node1 = stub('parent node1')
          parent_node2 = stub('parent node2')
          parent1 = stub('parent1', :ac_node => parent_node1)
          parent2 = stub('parent2', :ac_node => parent_node2)
          record = model_klass.new
          record.stub!(:new_record?).and_return(false)
          record.stub!(:parents).and_return([parent1, parent2])
          ::AccessControl::Model::Node.should_receive(:create!).
            with(:securable => record, :parents => [parent_node1, parent_node2])
          record.ac_node
        end

        it "doesn't try to create a node if this is a new record" do
          record = model_klass.new
          ::AccessControl::Model::Node.should_not_receive(:create!)
          record.ac_node
        end

        it "returns nil in the ac_node association if this is a new record" do
          record = model_klass.new
          record.ac_node.should be_nil
        end

        it "returns the ac_node association as the node created" do
          node = stub('node')
          record = model_klass.new
          record.stub!(:new_record?).and_return(false)
          ::AccessControl::Model::Node.stub(:create!).and_return(node)
          record.ac_node.should == node
        end

        it "doesn't try to create a node twice" do
          ::AccessControl::Model::Node.create_global_node!
          record = model_klass.new
          record.stub!(:new_record?).and_return(false)
          record.stub!(:id).and_return(1)
          record_node = ::AccessControl::Model::Node.create!(
            :securable => record
          )
          ::AccessControl::Model::Node.should_not_receive(:create!)
          record.ac_node
        end

        describe "when the object is not securable" do
          it "returns nil on ac_node association" do
            record = model_klass.new
            model_klass.stub(:securable?).and_return(false)
            record.ac_node.should be_nil
          end
        end

      end

      describe "when creating or saving" do

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

        it "updates parents of the node" do
          parent_node1 = stub('parent node1')
          parent_node2 = stub('parent node2')
          parent_node3 = stub('parent node3')
          parent_node4 = stub('parent node4')

          node = mock('node', :parents => [parent_node1, parent_node3])

          new_parent1 = stub('new parent1', :ac_node => parent_node2)
          new_parent2 = stub('new parent2', :ac_node => parent_node4)

          record = model_klass.new
          record.stub!(:new_record?).and_return(false)
          record.stub!(:id).and_return(1)
          record.stub!(:ac_node).and_return(node)
          record.stub!(:parents).and_return([new_parent1, new_parent2])

          node.should_receive(:parents=).with([parent_node2, parent_node4])
          record.save
        end

      end

      describe "when destroying" do
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

    describe "access permission" do
      # This permission is the permission applied to restricted queries (see in
      # query interface).
      it "can be defined in class level" do
        model_klass.access_permission 'some permission'
      end
      it "can be queried in class level" do
        model_klass.access_permission 'some permission'
        model_klass.access_permission.should == 'some permission'
      end
      it "defaults to config's value" do
        default = AccessControl.config.default_access_permission
        model_klass.access_permission.should == default
      end
      it "doesn't mess with the config's value" do
        old_value = AccessControl.config.default_access_permission
        model_klass.access_permission 'some permission'
        AccessControl.config.default_access_permission.should == old_value
      end
    end

    describe "query interface" do

      let(:principal) { Model::Principal.create!(:subject_type => 'User',
                                                 :subject_id => 1) }
      let(:role1) { Model::Role.create!(:name => 'A role') }
      let(:role2) { Model::Role.create!(:name => 'Another role') }
      let(:manager) { SecurityManager.new('a controller') }
      before do
        AccessControl.configure do |config|
          config.default_access_permission = 'view'
        end
        AccessControl.stub!(:get_security_manager).and_return(manager)
        manager.stub!(:principal_ids).and_return([principal.id])
        Model::Node.create_global_node!
        Model::SecurityPolicyItem.create!(:permission_name => 'view',
                                          :role_id => role1.id)
      end

      describe "#find" do

        it "returns only the records on which the principal has permissions" do
          record1 = model_klass.create!
          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => role1)
          record2 = model_klass.create!
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => role2)
          record3 = model_klass.create!
          result = model_klass.find(:all)
          result.should include(record1)
          result.should_not include(record2)
          result.should_not include(record3)
        end

        it "checks access permission only when the manager allows" do
          manager.stub!(:restrict_queries?).and_return(false)
          record1 = model_klass.create!
          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => role1)
          record2 = model_klass.create!
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => role2)
          record3 = model_klass.create!
          result = model_klass.find(:all)
          result.should include(record1)
          result.should include(record2)
          result.should include(record3)
        end

        it "doesn't mess with the order of items" do
          record1 = model_klass.create!
          record1.ac_node.assignments.create!(:principal => principal,
                                              :role => role1)
          record2 = model_klass.create!
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => role1)
          record2.ac_node.assignments.create!(:principal => principal,
                                              :role => role2)
          record3 = model_klass.create!
          result = model_klass.find(:all)
          result.should == [record1, record2]
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
