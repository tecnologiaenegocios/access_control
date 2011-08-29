require 'spec_helper'
require 'access_control/configuration'
require 'access_control/node'

module AccessControl
  describe Node do

    let(:global_node) do
      global_securable_type = Node.global_securable_type
      global_securable_id = Node.global_securable_id
      Node.find_by_securable_type_and_securable_id(
        global_securable_type, global_securable_id
      )
    end

    let(:manager) { Manager.new }

    def securable
      stub_model(SecurableObj)
    end

    before do
      Node.clear_global_node_cache
      AccessControl.stub(:manager).and_return(manager)
      manager.stub(:can_assign_or_unassign?).and_return(true)
      Principal.create_anonymous_principal!
      class Object::SecurableObj < ActiveRecord::Base
        set_table_name 'records'
      end
    end

    after do
      Object.send(:remove_const, 'SecurableObj')
    end

    describe "global node" do

      it "can create the global node" do
        Node.create_global_node!
      end

      it "can return the global object" do
        Node.create_global_node!
        Node.global.should == global_node
      end

      it "can return the global id" do
        Node.create_global_node!
        Node.global_id.should == global_node.id
      end

      it "returns nil if there's no global node" do
        Node.global.should be_nil
      end

      it "returns true in #global? if the node is the global one" do
        Node.create_global_node!
        Node.global.global?.should be_true
      end

      it "returns false in #global? if the node is not the global one" do
        Node.create_global_node!
        other_node = Node.create!(:securable => securable)
        other_node.global?.should be_false
      end

    end

    describe "#assignments" do

      before do
        Node.create_global_node!
      end

      it "destroys the dependant assignments when the node is destroyed" do
        node = Node.new(:securable_type => 'Foo', :securable_id => 1)
        assignment = stub_model(Assignment, :[]= => true, :save => true)
        node.assignments << assignment
        assignment.should_receive(:destroy)
        node.destroy
      end

      it "accepts nested attributes" do
        node = Node.new(
          :securable_type => 'Foo',
          :securable_id => 1,
          :assignments_attributes => {
            '0' => {:role_id => 1, :principal_id => 1}
          }
        )
        node.assignments.first.node_id.should == node.id
        node.assignments.first.role_id.should == 1
        node.assignments.first.principal_id.should == 1
      end

      it "allows destruction of assignments" do
        node = Node.new(:securable_type => 'Foo', :securable_id => 1)
        assignment = stub_model(Assignment, :[]= => true, :save => true)
        node.assignments << assignment
        # A little explanation of the "twice" bit: Rails adds two callbacks for
        # an autosave association, one for the has_many declaration and
        # another for the accepts_nested_attributes_for declaration.  This
        # makes the destroy method being called twice.  If the association
        # hasn't the accepts_nested_attributes_for stuff, only one callback
        # would exist and be called, but the method destroy would not if the
        # association were not autosave.
        assignment.should_receive(:destroy).twice
        node.update_attributes(:assignments_attributes => {
          '0' => {:id => assignment.to_param, :_destroy => '1'}
        })
      end

    end

    describe "#principal_roles" do

      it "returns only the roles belonging to the current principals" do
        Node.create_global_node!
        node = Node.create!(:securable_type => 'Foo', :securable_id => 1)
        principal1 = Principal.create!(:subject_type => 'User',
                                       :subject_id => 1)
        principal2 = Principal.create!(:subject_type => 'User',
                                       :subject_id => 2)
        principal3 = Principal.create!(:subject_type => 'User',
                                       :subject_id => 3)
        role1 = Role.create!(:name => 'Role 1')
        role2 = Role.create!(:name => 'Role 2')
        role3 = Role.create!(:name => 'Role 3')
        assignment1 = Assignment.create!(:role_id => role1.id,
                                         :principal_id => principal1.id,
                                         :node_id => node.id)
        assignment2 = Assignment.create!(:role_id => role2.id,
                                         :principal_id => principal2.id,
                                         :node_id => node.id)
        assignment3 = Assignment.create!(:role_id => role3.id,
                                         :principal_id => principal3.id,
                                         :node_id => node.id)
        manager.stub!(:principal_ids).
          and_return([principal1.id, principal3.id])
        node.reload.principal_roles.should include(role1)
        node.principal_roles.should include(role3)
        node.principal_roles.should_not include(role2)
      end

      describe "conditions optimization" do

        describe "conditions with single principal" do
          it "uses the single element of the `principal_ids` from manager" do
            manager.should_receive(:principal_ids).and_return(['principal id'])
            Node.reflections[:principal_roles].
              through_reflection.options[:conditions].should == {
                :principal_id => 'principal id'
              }
          end
        end

        describe "conditions with multiple principals" do
          it "passes along all principal ids from manager in an array" do
            manager.should_receive(:principal_ids).
              and_return(['principal id1', 'principal id2'])
            Node.reflections[:principal_roles].
              through_reflection.options[:conditions].should == {
                :principal_id => ['principal id1', 'principal id2']
              }
          end
        end
      end

    end

    describe "#assignments_with_roles" do
      describe "Assignment conformance with expected interface" do
        it_has_class_method(Assignment, :with_roles)
      end
      it "calls .with_roles named scope on assignments association" do
        node = Node.new
        roles = 'some roles to filter'
        node.stub(:assignments => mock('assignments'))
        node.assignments.should_receive(:with_roles).with(roles).
          and_return('the filtered assignments')
        node.assignments_with_roles(roles).should == 'the filtered assignments'
      end
    end

    describe "getting ancestors" do

      let(:securable_class) { Class.new }

      def securable; securable_class.new; end

      let(:assoc_proxy1)   { mock('parent record or records 1') }
      let(:assoc_proxy2)   { mock('parent record or records 2') }
      let(:record)         { securable }
      let(:node)           { Node.new }
      let(:parent_node1)   { mock('parent node1') }
      let(:parent_node2)   { mock('parent node2') }
      let(:ancestor_node1) { mock('ancestor node or nodes 1') }
      let(:ancestor_node2) { mock('ancestor node or nodes 2') }
      let(:context1)       { mock('context1',
                                  :nodes => Set.new([parent_node1])) }
      let(:context2)       { mock('context2',
                                  :nodes => Set.new([parent_node2])) }
      let(:global)         { mock('the global node') }

      before do
        node.stub(:securable => record)
        record.stub(:parent1).and_return(assoc_proxy1)
        record.stub(:parent2).and_return(assoc_proxy2)
        SecurityContext.stub(:new).with(assoc_proxy1).and_return(context1)
        SecurityContext.stub(:new).with(assoc_proxy2).and_return(context2)
        Node.stub(:global).and_return(global)
      end

      describe "#strict_unblocked_ancestors" do

        def get_nodes
          node.strict_unblocked_ancestors
        end

        before do
          parent_node1.
            stub(:unblocked_ancestors => Set.new([ancestor_node1]))
          parent_node2.
            stub(:unblocked_ancestors => Set.new([ancestor_node2]))
        end

        it "gets the node's securable" do
          node.should_receive(:securable).and_return(record)
          get_nodes
        end

        describe "when the record class is Inheritance-aware" do

          before do
            record.class.send(:include, Inheritance)
            record.stub(:inherits_permissions_from).
              and_return([:parent1, :parent2])
          end

          it "returns only the global node when no inheritance" do
            record.stub(:inherits_permissions_from).and_return([])
            get_nodes.should == Set.new([global])
          end

          describe "when the node is not blocked" do

            before { node.stub(:block).and_return(false) }

            it "gets the securable's associated parent records" do
              record.should_receive(:inherits_permissions_from).
                and_return([:parent1, :parent2])
              record.should_receive(:parent1).and_return(assoc_proxy1)
              record.should_receive(:parent2).and_return(assoc_proxy2)
              get_nodes
            end

            it "gets their nodes using a security context" do
              SecurityContext.should_receive(:new).with(assoc_proxy1).
                and_return(context1)
              SecurityContext.should_receive(:new).with(assoc_proxy2).
                and_return(context2)
              context1.should_receive(:nodes).
                and_return(Set.new([parent_node1]))
              context2.should_receive(:nodes).
                and_return(Set.new([parent_node2]))
              get_nodes
            end

            it "gets their unblocked ancestors" do
              parent_node1.should_receive(:unblocked_ancestors).
                and_return(Set.new([ancestor_node1]))
              parent_node2.should_receive(:unblocked_ancestors).
                and_return(Set.new([ancestor_node2]))
              get_nodes
            end

            it "returns their ancestors merged with the global node" do
              get_nodes.should ==
                Set.new([ancestor_node1, ancestor_node2, global])
            end

          end

          describe "when the node is blocked" do
            before { node.stub(:block).and_return(true) }
            it "returns only the global node" do
              get_nodes.should == Set.new([global])
            end
          end

        end

        describe "when the securable class is not Inheritance-aware" do
          it "returns only the global node" do
            get_nodes.should == Set.new([global])
          end
        end

      end

      describe "#strict_ancestors" do

        # Works as #strict_unblocked_ancestors, but doesn't care if the node is
        # blocked.

        def get_nodes
          node.strict_ancestors
        end

        before do
          parent_node1.stub(:ancestors => Set.new([ancestor_node1]))
          parent_node2.stub(:ancestors => Set.new([ancestor_node2]))
        end

        it "gets the node's securable" do
          node.should_receive(:securable).and_return(record)
          get_nodes
        end

        describe "when the record class is Inheritance-aware" do

          before do
            record.class.send(:include, Inheritance)
            record.stub(:inherits_permissions_from).
              and_return([:parent1, :parent2])
            node.stub(:block).and_return(true)
          end

          it "returns only the global node when no inheritance" do
            record.stub(:inherits_permissions_from).and_return([])
            get_nodes.should == Set.new([global])
          end

          it "gets the securable's associated parent records" do
            record.should_receive(:inherits_permissions_from).
              and_return([:parent1, :parent2])
            record.should_receive(:parent1).and_return(assoc_proxy1)
            record.should_receive(:parent2).and_return(assoc_proxy2)
            get_nodes
          end

          it "gets their nodes using a security context" do
            SecurityContext.should_receive(:new).with(assoc_proxy1).
              and_return(context1)
            SecurityContext.should_receive(:new).with(assoc_proxy2).
              and_return(context2)
            context1.should_receive(:nodes).
              and_return(Set.new([parent_node1]))
            context2.should_receive(:nodes).
              and_return(Set.new([parent_node2]))
            get_nodes
          end

          it "gets their ancestors" do
            parent_node1.should_receive(:ancestors).
              and_return(Set.new([ancestor_node1]))
            parent_node2.should_receive(:ancestors).
              and_return(Set.new([ancestor_node2]))
            get_nodes
          end

          it "returns their ancestors merged with the global node" do
            get_nodes.should ==
              Set.new([ancestor_node1, ancestor_node2, global])
          end

        end

        describe "when the securable class is not Inheritance-aware" do
          it "returns only the global node" do
            get_nodes.should == Set.new([global])
          end
        end

      end

      describe "#unblocked_ancestors" do

        # Works like the #strict_unblocked_ancestors, but returns self in
        # addition to those nodes.

        it "returns self in addition the strict unblocked nodes" do
          whatever = stub('whatever')
          node.stub(:strict_unblocked_ancestors).and_return(Set.new([whatever]))
          node.unblocked_ancestors.should == Set.new([node, whatever])
        end
      end

      describe "#ancestors" do

        # Works like the #strict_ancestors, but returns self in addition to
        # those nodes.

        it "returns self in addition the strict unblocked nodes" do
          whatever = stub('whatever')
          node.stub(:strict_ancestors).and_return(Set.new([whatever]))
          node.ancestors.should == Set.new([node, whatever])
        end
      end
    end

    describe ".granted_for" do

      # Gets nodes for a securable type and principal ids with the requested
      # permissions

      let(:results)       { stub('results') }
      let(:principal_ids) { ['principal id 1', 'principal id 2'] }
      let(:permissions)   { Set.new(['permission 1', 'permission 2']) }

      def call_method(conditions={})
        Node.granted_for('SecurableType', principal_ids, permissions,
                         conditions)
      end

      before do
        Node.stub(:find).and_return(results)
      end

      it "does the job for a type and principal ids with permissions" do
        Node.should_receive(:find).with(
          :all,
          :joins => { :assignments => { :role => :security_policy_items } },
          :conditions => {
            :securable_type => 'SecurableType',
            :'ac_assignments.principal_id' => principal_ids,
            :'ac_security_policy_items.permission' => permissions.to_a,
          }
        ).and_return(results)
        call_method
      end

      it "merges conditions passed" do
        Node.should_receive(:find).with(:all, hash_including(
          :conditions => hash_including(
            :custom_condition => 'custom condition'
          )
        )).and_return(results)
        call_method(:custom_condition => 'custom condition')
      end

      it "return the results of the find call" do
        call_method.should == results
      end

      describe "with a single principal id" do
        let(:principal_ids) { ['principal id'] }
        it "extracts the principal id" do
          Node.should_receive(:find).with(:all, hash_including(
            :conditions => hash_including(
              :'ac_assignments.principal_id' => 'principal id'
            )
          )).and_return(results)
          call_method
        end
      end

      describe "with a single permission" do
        let(:permissions) { Set.new(['permission']) }
        it "extracts the permission" do
          Node.should_receive(:find).with(:all, hash_including(
            :conditions => hash_including(
              :'ac_security_policy_items.permission' => 'permission'
            )
          )).and_return(results)
          call_method
        end
      end

    end

    describe ".blocked_for" do

      # Gets all nodes with block = 1 or true for the securable type.

      it "gets blocked nodes for a securable type" do
        Node.create_global_node!
        manager.stub(:can!)
        node1 = Node.create!(:securable_type => 'SecurableType 1',
                             :securable_id => 1)
        node2 = Node.create!(:securable_type => 'SecurableType 1',
                             :securable_id => 2, :block => 1)
        node3 = Node.create!(:securable_type => 'SecurableType 2',
                             :securable_id => 1)
        Node.blocked_for('SecurableType 1').should == [node2]
      end

    end

    describe "automatic role assignment" do

      let(:role1) { Role.create!(:name => 'owner') }
      let(:role2) { Role.create!(:name => 'manager') }

      before do
        manager.stub!(:principal_ids => [1, 2, 3], :can! => nil)
        role1; role2;
      end

      describe "when there's one or more default roles" do

        it "assigns the default roles to current principals in the node" do
          AccessControl.config.stub!(:default_roles_on_create).
            and_return(Set.new(['owner', 'manager']))

          node = Node.create!(:securable => securable).reload

          assignments = node.assignments.map do |a|
            { :node_id => a.node_id, :role_id => a.role_id,
              :principal_id => a.principal_id}
          end

          assignments.should include(:node_id => node.id,
                                     :principal_id => 1,
                                     :role_id => role1.id)
          assignments.should include(:node_id => node.id,
                                     :principal_id => 1,
                                     :role_id => role2.id)
          assignments.should include(:node_id => node.id,
                                     :principal_id => 2,
                                     :role_id => role1.id)
          assignments.should include(:node_id => node.id,
                                     :principal_id => 2,
                                     :role_id => role2.id)
          assignments.should include(:node_id => node.id,
                                     :principal_id => 3,
                                     :role_id => role1.id)
          assignments.should include(:node_id => node.id,
                                     :principal_id => 3,
                                     :role_id => role2.id)
        end

      end

      describe "when there's no default roles" do
        it "doesn't assigns the node to any role" do
          AccessControl.config.stub!(:default_roles_on_create).
            and_return(nil)
          node = Node.create!(:securable => securable).reload
          node.assignments.should be_empty
        end
      end

    end

    describe "blocking and unblocking" do

      let(:node) { Node.new }

      it "defaults to unblocked (block == false)" do
        node.block.should be_false
      end

      describe "when blocking" do

        it "checks if the user has 'change_inheritance_blocking'" do
          manager.should_receive(:can!).
            with('change_inheritance_blocking', node)
          node.block = true
        end

      end

      describe "when unblocking" do

        before do
          manager.stub(:can!)
          node.block = true
        end

        it "checks if the user has 'change_inheritance_blocking'" do
          manager.should_receive(:can!).
            with('change_inheritance_blocking', node)
          node.block = false
        end

      end

    end

  end
end
