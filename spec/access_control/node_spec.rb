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

    let(:manager) { SecurityManager.new }

    def securable
      stub_model(SecurableObj)
    end

    before do
      Node.clear_global_node_cache
      AccessControl.stub(:security_manager).and_return(manager)
      manager.stub(:can_assign_or_unassign?).and_return(true)
      Principal.create_anonymous_principal!
      class Object::SecurableObj < ActiveRecord::Base
        set_table_name 'records'
      end
    end

    after do
      Object.send(:remove_const, 'SecurableObj')
    end

    it "is not securable" do
      Node.securable?.should be_false
    end

    describe "global node" do

      it "creates the global node" do
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

      it "complains if the parent is set in the global node" do
        Node.create_global_node!
        other_node = Node.create!(:securable => securable)
        lambda {
          global = Node.global
          global.parents << other_node
        }.should raise_exception(::AccessControl::ParentError)
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

      it "has itself as the only ancestor" do
        Node.create_global_node!
        Node.global.ancestors.should == [Node.global]
      end

    end

    it "complains if the global node doesn't exist" do
      lambda {
        Node.create!(:securable => securable)
      }.should raise_exception(::AccessControl::NoGlobalNode)
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
        principal1 = Principal.create!(:subject_type => 'User', :subject_id => 1)
        principal2 = Principal.create!(:subject_type => 'User', :subject_id => 2)
        principal3 = Principal.create!(:subject_type => 'User', :subject_id => 3)
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
        manager.stub!(:principal_ids).and_return([principal1.id, principal3.id])
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

    describe "tree management" do

      let(:ancestor) do
        Node.create!(:securable => securable)
      end

      let(:parent) do
        Node.create!(:securable => securable, :parents => [ancestor])
      end

      let(:new_parent) do
        Node.create!(:securable => securable, :parents => [ancestor])
      end

      let(:node) do
        Node.create!(:securable => securable, :parents => [parent])
      end

      let(:new_node) do
        Node.create!(:securable => securable, :parents => [new_parent])
      end

      let(:child) do
        Node.create!(:securable => securable, :parents => [node])
      end

      let(:descendant) do
        Node.create!(:securable => securable, :parents => [child])
      end

      before do
        Node.create_global_node!
        descendant # "wake-up" all the tree.
        new_node
      end

      describe "when a new record is created" do

        it "complains if the parent is set to the global_node" do
          lambda {
            Node.create!(:securable => securable, :parents => [global_node])
          }.should raise_exception(::AccessControl::ParentError)
        end

        it "creates a single path pointing to the record itself" do
          r = Node.create!(:securable => securable).reload
          r.ancestors.should include(r)
          r.descendants.should == [r]
        end

        it "creates a path pointing from the global node to itself" do
          r = Node.create!(:securable => securable).reload
          r.ancestors.should include(global_node)
        end

        it "creates the ancestor paths based on the parents' ancestors" do
          ancestor = Node.create!(:securable => securable)
          parent = Node.create!(:securable => securable,
                                :parents => [ancestor])
          child = Node.create!(:securable => securable, :parents => [parent])
          child.ancestors.should include(ancestor)
          child.ancestors.should include(parent)
          child.descendants.should_not include(ancestor)
          child.descendants.should_not include(parent)
        end

        describe "automatic node assignment" do

          let(:role1) { Role.create!(:name => 'owner') }
          let(:role2) { Role.create!(:name => 'manager') }

          before do
            manager.stub!(:principal_ids => [1, 2, 3], :verify_access! => nil)
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
      end

      describe "when parent is added" do

        before do
          node.parents << new_parent
        end

        it "increases the ancestor list" do
          node.ancestors.should include(node)
          node.ancestors.should include(parent)
          node.ancestors.should include(new_parent)
          node.ancestors.should include(ancestor)
          node.ancestors.should include(global_node)
          node.ancestors.size.should == 5
        end

        it "increases the descendant list of the new parent" do
          new_parent.descendants.should include(new_parent)
          new_parent.descendants.should include(new_node)
          new_parent.descendants.should include(node)
          new_parent.descendants.should include(child)
          new_parent.descendants.should include(descendant)
          new_parent.descendants.size.should == 5
        end

        it "keeps its descendants" do
          node.descendants.should include(node)
          node.descendants.should include(child)
          node.descendants.should include(descendant)
          node.descendants.size.should == 3
        end

        it "keeps the ancestors of the new parent" do
          new_parent.ancestors.should include(new_parent)
          new_parent.ancestors.should include(ancestor)
          new_parent.ancestors.should include(global_node)
        end

        it "keeps the ancestors of the descendants of the new parent" do
          new_node.ancestors.should include(new_node)
          new_node.ancestors.should include(new_parent)
          new_node.ancestors.should include(ancestor)
          new_node.ancestors.should include(global_node)
        end

        it "keeps the descendants of the descendants of the new parent" do
          new_node.descendants.should == [new_node]
        end

        it "updates the ancestors of its descendants" do
          child.ancestors.should include(child)
          child.ancestors.should include(node)
          child.ancestors.should include(parent)
          child.ancestors.should include(new_parent)
          child.ancestors.should include(ancestor)
          child.ancestors.should include(global_node)
          child.ancestors.size.should == 6
          descendant.ancestors.should include(descendant)
          descendant.ancestors.should include(child)
          descendant.ancestors.should include(node)
          descendant.ancestors.should include(parent)
          descendant.ancestors.should include(new_parent)
          descendant.ancestors.should include(ancestor)
          descendant.ancestors.should include(global_node)
          descendant.ancestors.size.should == 7
        end

      end

      describe "when parent is removed" do

        before do
          node.parents << new_parent
          node.parents.delete(new_parent)
        end

        it "decreases the ancestor list" do
          node.ancestors.should include(node)
          node.ancestors.should include(parent)
          node.ancestors.should include(ancestor)
          node.ancestors.should include(global_node)
          node.ancestors.should_not include(new_parent)
          node.ancestors.size.should == 4
        end

        it "decreases the descendant list of the deleted parent" do
          new_parent.descendants.should include(new_parent)
          new_parent.descendants.should include(new_node)
          new_parent.descendants.should_not include(node)
          new_parent.descendants.size.should == 2
        end

        it "keeps its descendants" do
          node.descendants.should include(node)
          node.descendants.should include(child)
          node.descendants.should include(descendant)
          node.descendants.size.should == 3
        end

        it "keeps the ancestors of the deleted parent" do
          new_parent.ancestors.should include(new_parent)
          new_parent.ancestors.should include(ancestor)
          new_parent.ancestors.should include(global_node)
        end

        it "keeps the ancestors of the descendants of the deleted parent" do
          new_node.ancestors.should include(new_node)
          new_node.ancestors.should include(new_parent)
          new_node.ancestors.should include(ancestor)
          new_node.ancestors.should include(global_node)
        end

        it "keeps the descendants of the descendants of the deleted parent" do
          new_node.descendants.should == [new_node]
        end

        it "updates the ancestors of its descendants" do
          child.ancestors.should include(child)
          child.ancestors.should include(node)
          child.ancestors.should include(parent)
          child.ancestors.should include(ancestor)
          child.ancestors.should include(global_node)
          child.ancestors.should_not include(new_parent)
          child.ancestors.size.should == 5
          descendant.ancestors.should include(descendant)
          descendant.ancestors.should include(child)
          descendant.ancestors.should include(node)
          descendant.ancestors.should include(parent)
          descendant.ancestors.should include(ancestor)
          descendant.ancestors.should include(global_node)
          descendant.ancestors.should_not include(new_parent)
          descendant.ancestors.size.should == 6
        end

      end

      describe "blocking and unblocking" do

        it "defaults to unblocked (block == false)" do
          Node.new.block.should be_false
        end

        it "creates connected only with self and global node if blocked" do
          r = Node.create!(
            :securable => securable,
            :parents => [parent],
            :block => true
          )
          r.reload.ancestors.should include(global_node)
          r.reload.ancestors.should include(r)
          r.reload.ancestors.size.should == 2
        end

        it "keeps parent even if blocked" do
          r = Node.create!(
            :securable => securable,
            :parents => [parent],
            :block => true
          )
          r.reload.parents.should == [parent]
        end

        describe "when blocking" do

          it "checks if the user has 'change_inheritance_blocking'" do
            manager.should_receive(:verify_access!).
              with(node, 'change_inheritance_blocking')
            node.block = true
            node.save!
          end

          describe "when the principal has 'change_inheritance_blocking'" do

            before do
              manager.stub(:verify_access!)
              node.block = true
              node.save!
            end

            it "removes ancestors" do
              node.ancestors.should include(node)
              node.ancestors.should_not include(parent)
              node.ancestors.should_not include(ancestor)
            end

            it "keeps the global node as an ancestor" do
              node.ancestors.should include(global_node)
            end

            it "keeps its descendants" do
              node.descendants.should include(node)
              node.descendants.should include(child)
              node.descendants.should include(descendant)
            end

            it "removes ancestors for its descendants" do
              child.ancestors.should include(child)
              child.ancestors.should include(node)
              child.ancestors.should_not include(parent)
              child.ancestors.should_not include(ancestor)
              descendant.ancestors.should include(descendant)
              descendant.ancestors.should include(child)
              descendant.ancestors.should include(node)
              descendant.ancestors.should_not include(parent)
              descendant.ancestors.should_not include(ancestor)
            end

            it "keeps the global node as an ancestor of its decendants" do
              child.ancestors.should include(global_node)
              descendant.ancestors.should include(global_node)
            end

            it "keeps strict ancestors through #strict_unblocked_ancestors" do
              node.strict_unblocked_ancestors.should include(parent)
              node.strict_unblocked_ancestors.should include(ancestor)
              node.strict_unblocked_ancestors.should include(global_node)
              node.strict_unblocked_ancestors.size.should == 3
            end

          end

        end

        describe "when unblocking" do

          before do
            manager.stub(:verify_access!)
            node.block = true
            node.save!
          end

          it "checks if the user has 'change_inheritance_blocking'" do
            manager.should_receive(:verify_access!).
              with(node, 'change_inheritance_blocking')
            node.block = false
            node.save!
          end

          describe "when the principal has 'change_inheritance_blocking'" do

            before do
              node.block = false
              node.save!
            end

            it "reconnects ancestors" do
              node.ancestors.should include(node)
              node.ancestors.should include(parent)
              node.ancestors.should include(ancestor)
            end

            it "keeps the global node as an ancestor" do
              node.ancestors.should include(global_node)
            end

            it "keeps its descendants" do
              node.descendants.should include(node)
              node.descendants.should include(child)
              node.descendants.should include(descendant)
            end

            it "reconnects ancestors for its descendants" do
              child.ancestors.should include(child)
              child.ancestors.should include(node)
              child.ancestors.should include(parent)
              child.ancestors.should include(ancestor)
              descendant.ancestors.should include(descendant)
              descendant.ancestors.should include(child)
              descendant.ancestors.should include(node)
              descendant.ancestors.should include(parent)
              descendant.ancestors.should include(ancestor)
            end

            it "keeps the global node as an ancestor of its decendants" do
              child.ancestors.should include(global_node)
              descendant.ancestors.should include(global_node)
            end

          end

        end

      end

    end

  end
end
