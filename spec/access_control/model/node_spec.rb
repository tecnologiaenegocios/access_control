require 'spec_helper'

module AccessControl::Model
  describe Node do

    let(:global_node) do
      global_securable_type = Node.global_securable_type
      global_securable_id = Node.global_securable_id
      Node.find_by_securable_type_and_securable_id(
        global_securable_type, global_securable_id
      )
    end

    def securable
      SecurableObj.create!
    end

    before do
      Node.clear_global_node_cache
      class Object::SecurableObj < ActiveRecord::Base
        include AccessControl::ModelSecurity::InstanceMethods
        set_table_name 'records'
        def create_nodes
          # We disable automatic node creation since it doesn't belong to this
          # spec.
        end
      end
    end

    after do
      Object.send(:remove_const, 'SecurableObj')
    end

    it "cannot be wrapped by a security proxy" do
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

    end

    it "complains if the global node doesn't exist" do
      lambda {
        Node.create!(:securable => securable)
      }.should raise_exception(::AccessControl::NoGlobalNode)
    end

    describe "#principal_assignments" do

      let(:manager) { ::AccessControl::SecurityManager.new('a controller') }

      before do
        ::AccessControl.stub!(:get_security_manager).and_return(manager)
      end

      it "returns only the assignments belonging to the current principals" do
        Node.create_global_node!
        node = Node.create!(:securable_type => 'Foo', :securable_id => 1)
        principal1 = Principal.create!(:subject_type => 'User', :subject_id => 1)
        principal2 = Principal.create!(:subject_type => 'User', :subject_id => 2)
        principal3 = Principal.create!(:subject_type => 'User', :subject_id => 3)
        assignment1 = Assignment.create!(:role_id => 0,
                                         :principal_id => principal1.id,
                                         :node_id => node.id)
        assignment2 = Assignment.create!(:role_id => 0,
                                         :principal_id => principal2.id,
                                         :node_id => node.id)
        assignment3 = Assignment.create!(:role_id => 0,
                                         :principal_id => principal3.id,
                                         :node_id => node.id)
        manager.stub!(:principal_ids).and_return([principal1.id, principal3.id])
        node.reload.principal_assignments.should include(assignment1)
        node.principal_assignments.should include(assignment3)
        node.principal_assignments.should_not include(assignment2)
      end

      describe "conditions optimization" do
        describe "conditions with single principal" do
          it "uses the single element of the `principal_ids` from manager" do
            manager.should_receive(:principal_ids).and_return(['principal id'])
            Node.reflections[:principal_assignments].
              options[:conditions].should == {
                :principal_id => 'principal id'
              }
          end
        end
        describe "conditions with multiple principals" do
          it "passes along all principal ids from manager in an array" do
            manager.should_receive(:principal_ids).
              and_return(['principal id1', 'principal id2'])
            Node.reflections[:principal_assignments].
              options[:conditions].should == {
                :principal_id => ['principal id1', 'principal id2']
              }
          end
        end
      end

    end

    describe "#assignments" do

      it "returns all assignments, regardless the principals" do
        Node.create_global_node!
        node = Node.create!(:securable_type => 'Foo', :securable_id => 1)
        principal1 = Principal.create!(:subject_type => 'User', :subject_id => 1)
        principal2 = Principal.create!(:subject_type => 'User', :subject_id => 2)
        principal3 = Principal.create!(:subject_type => 'User', :subject_id => 3)
        assignment1 = Assignment.create!(:role_id => 0,
                                         :principal_id => principal1.id,
                                         :node_id => node.id)
        assignment2 = Assignment.create!(:role_id => 0,
                                         :principal_id => principal2.id,
                                         :node_id => node.id)
        assignment3 = Assignment.create!(:role_id => 0,
                                         :principal_id => principal3.id,
                                         :node_id => node.id)
        node.reload.assignments.should include(assignment1)
        node.assignments.should include(assignment3)
        node.assignments.should include(assignment2)
      end

      it "destroys the dependant assignments when the node is destroyed" do
        Node.create_global_node!
        node = Node.create!(:securable_type => 'Foo', :securable_id => 1)
        assignment = Assignment.create!(:role_id => 0,
                                        :principal_id => 0,
                                        :node_id => node.id)
        node.destroy
        Assignment.count.should == 0
      end

    end

    describe "#has_permission?" do

      let(:parent) { stub_model(Node) }
      let(:node) { stub_model(Node) }
      let(:role1) do
        stub('role1', :security_policy_items => [
          stub(:permission_name => 'permission 1'),
        ])
      end
      let(:role2) do
        stub('role2', :security_policy_items => [
          stub(:permission_name => 'permission 2'),
        ])
      end
      let(:role3) do
        stub('role3', :security_policy_items => [
          stub(:permission_name => 'permission 3'),
          stub(:permission_name => 'permission 4'),
        ])
      end
      let(:role4) do
        stub('role4', :security_policy_items => [
          stub(:permission_name => 'permission 5'),
          stub(:permission_name => 'permission 6'),
        ])
      end

      before do
        node.stub!(:principal_assignments => [
          stub('an assignment', :role => role1),
          stub('another assignment', :role => role2)
        ])
        parent.stub!(:principal_assignments => [
          stub('an assignment', :role => role3),
          stub('another assignment', :role => role4)
        ])
        node.stub!(:ancestors).and_return([parent, node])
      end

      it "returns true when the user has the required permission" do
        node.has_permission?('permission 6').should be_true
      end

      it "returns false when the user has not the permission" do
        node.has_permission?('permission 7001').should be_false
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

          before do
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

        end

        describe "when unblocking" do

          before do
            node.block = true
            node.save!
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
