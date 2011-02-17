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

      describe "tree management" do

        let(:test_object) do
          object = Class.new
          object.extend(ModelSecurity::ClassMethods)
          object
        end

        describe "parent association" do

          it "can be defined" do
            test_object.parent_association(:test)
            test_object.parent_association.should == :test
          end

        end

        describe "child associations" do

          it "is empty by default" do
            test_object.child_associations.should be_empty
          end

          it "can be defined" do
            test_object.child_associations(:child1, :child2)
            test_object.child_associations.should == [:child1, :child2]
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

      describe "child node list" do

        before do
          model_klass.send(:include, ModelSecurity::InstanceMethods)
        end

        it "is empty by default" do
          model_klass.new.children.should be_empty
        end

        describe "when there's one child association" do

          before do
            model_klass.class_eval do
              child_associations :test
            end
          end

          describe "and the association is single" do

            it "wraps the value of the association in an array" do
              model_klass.class_eval do
                def test
                  'a single object'
                end
              end
              model_klass.new.children.should == ['a single object']
            end

          end

          describe "and the association is collection" do

            it "return the values of the association" do
              model_klass.class_eval do
                def test
                  ['many', 'objects']
                end
              end
              model_klass.new.children.should == ['many', 'objects']
            end

          end

        end

        describe "when there's many child associations" do

          before do
            model_klass.class_eval do
              child_associations :child1, :child2
              def child1
                'single'
              end
              def child2
                ['multiple']
              end
            end
          end

          it "returns an array containing the records of the associations" do
            model_klass.new.children.size.should == 2
            model_klass.new.children.should include('single')
            model_klass.new.children.should include('multiple')
          end

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

        it "updates children of the node on save" do
          parent_node1 = stub('parent_node1')
          parent_node2 = stub('parent_node2')
          parent1 = stub('parent1', :ac_node => parent_node1)
          parent2 = stub('parent2', :ac_node => parent_node2)
          node1 = mock('node1')
          node2 = mock('node2')
          child1 = model_klass.new
          child1.stub!(:ac_node => node1, :parents => [parent1])
          child2 = model_klass.new
          child2.stub!(:ac_node => node2, :parents => [parent2])
          record = model_klass.new
          record.stub!(:children).and_return([child1, child2])
          node1.should_receive(:parents=).with([parent_node1])
          node2.should_receive(:parents=).with([parent_node2])
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
