require 'spec_helper'
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

    end

    it "complains if the global node doesn't exist" do
      lambda {
        Node.create!(:securable => securable)
      }.should raise_exception(::AccessControl::NoGlobalNode)
    end

    describe "#principal_assignments" do

      let(:manager) { ::AccessControl::SecurityManager.new('a controller') }

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
        AccessControl.stub!(:get_security_manager).and_return(manager)
        manager.stub!(:principal_ids).and_return([principal1.id, principal3.id])
        node.reload.principal_assignments.should include(assignment1)
        node.principal_assignments.should include(assignment3)
        node.principal_assignments.should_not include(assignment2)
      end

      describe "conditions optimization" do

        before do
          AccessControl.stub!(:get_security_manager).and_return(manager)
        end

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

      before do
        Node.create_global_node!
      end

      it "returns all assignments, regardless the principals" do
        node = Node.create!(:securable_type => 'Foo', :securable_id => 1)
        principal1 = Principal.create!(:subject_type => 'User',
                                       :subject_id => 1)
        principal2 = Principal.create!(:subject_type => 'User',
                                       :subject_id => 2)
        principal3 = Principal.create!(:subject_type => 'User',
                                       :subject_id => 3)
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
        node = Node.create!(:securable_type => 'Foo', :securable_id => 1)
        assignment = Assignment.create!(:role_id => 0,
                                        :principal_id => 0,
                                        :node_id => node.id)
        node.destroy
        Assignment.count.should == 0
      end

      it "accepts nested attributes" do
        node = Node.create!(
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
        node = Node.create!(:securable_type => 'Foo', :securable_id => 1)
        assignment = Assignment.create!(:role_id => 0,
                                        :principal_id => 0,
                                        :node_id => node.id)
        node.reload.update_attributes(
          :assignments_attributes => {
            '0' => {:id => assignment.to_param, :_destroy => '1'}
          }
        )
        node.reload.assignments.should be_empty
      end

    end

    describe "permissions API" do

      let(:parent) { stub_model(Node) }
      let(:node) { stub_model(Node) }
      let(:role1) do
        stub_model(Role, :security_policy_items => [
          stub(:permission_name => 'permission 1'),
        ])
      end
      let(:role2) do
        stub_model(Role, :security_policy_items => [
          stub(:permission_name => 'permission 2'),
        ])
      end
      let(:role3) do
        stub_model(Role, :security_policy_items => [
          stub(:permission_name => 'permission 3'),
          stub(:permission_name => 'permission 4'),
        ])
      end
      let(:role4) do
        stub_model(Role, :security_policy_items => [
          stub(:permission_name => 'permission 5'),
          stub(:permission_name => 'permission 6'),
        ])
      end

      before do
        node.stub!(:principal_assignments => [
          stub('an assignment', :role => role1),
          stub('another assignment', :role => role2)
        ])
        parent.stub!(
          :principal_assignments => [
            stub('an assignment', :role => role3),
            stub('another assignment', :role => role4)
          ],
          :strict_ancestors => []
        )
        node.stub!(:ancestors).and_return([parent, node])
        node.stub!(:strict_ancestors).and_return([parent])
      end

      describe "#has_permissions?" do
        it "returns true when the user has the required permission" do
          node.has_permission?('permission 6').should be_true
        end

        it "returns false when the user has not the permission" do
          node.has_permission?('permission 7001').should be_false
        end
      end

      describe "#permission_names" do
        it "returns the permissions in the node for the current principal" do
          node.permission_names.should == Set.new([
            'permission 1',
            'permission 2',
            'permission 3',
            'permission 4',
            'permission 5',
            'permission 6',
          ])
        end
      end

      describe "#current_roles" do
        it "returns the roles that are assigned to the current principal" do
          node.current_roles.should == Set.new([role1, role2, role3, role4])
          parent.current_roles.should == Set.new([role3, role4])
        end
      end

      describe "#inherited_roles_for_all_principals(filter_roles)" do

        let(:principal1) { stub_model(Principal) }
        let(:principal2) { stub_model(Principal) }
        let(:roles) { [role1, role2, role3, role4] }
        let(:role_ids) { roles.map(&:id) }
        let(:ancestor) { stub_model(Node) }
        let(:global) { stub_model(Node, :global? => true) }
        let(:parent_assignments) { mock('assignments association') }
        let(:ancestor_assignments) { mock('assignments association') }
        let(:global_assignments) { mock('assignments association') }

        before do
          parent.should_receive(:assignments).and_return(parent_assignments)
          ancestor.should_receive(:assignments).and_return(ancestor_assignments)
          global.should_receive(:assignments).and_return(global_assignments)

          node.stub!(:strict_unblocked_ancestors).
            and_return([parent, ancestor, global])

          parent_assignments.should_receive(:find).with(
            :all,
            :conditions => {:role_id => role_ids}
          ).and_return([])
          ancestor_assignments.should_receive(:find).with(
            :all,
            :conditions => {:role_id => role_ids}
          ).and_return([
            stub(:role_id => role1.id, :principal_id => principal1.id),
            stub(:role_id => role1.id, :principal_id => principal2.id),
            stub(:role_id => role3.id, :principal_id => principal1.id),
          ])
          global_assignments.should_receive(:find).with(
            :all,
            :conditions => {:role_id => role_ids}
          ).and_return([
            stub(:role_id => role2.id, :principal_id => principal1.id),
            stub(:role_id => role3.id, :principal_id => principal1.id),
          ])

          @items = node.inherited_roles_for_all_principals(roles)
        end

        it "returns as many items as principals with assignments" do
          @items.size.should == 2
        end

        it "returns a hash keyed by principal ids" do
          @items.keys.sort.should == [principal1.id, principal2.id].sort
        end

        it "returns values as hashes keyed by role ids, only requested ones" do
          Set.new(@items.map{|k, v| v.keys}.flatten).
            should be_subset(Set.new(role_ids))
        end

        it "returns a set of 'global' and 'inherited' strings or nil" do
          @items[principal1.id][role1.id].should == Set.new(['inherited'])
          @items[principal1.id][role2.id].should == Set.new(['global'])
          @items[principal1.id][role3.id].should == Set.new(['inherited',
                                                             'global'])
          @items[principal2.id][role2.id].should be_nil
          @items[principal2.id][role1.id].should == Set.new(['inherited'])
          @items[principal2.id][role3.id].should be_nil
        end
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

          describe "when there's no security manager" do

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

            it "keeps strict ancestors through #strict_unblocked_ancestors" do
              node.strict_unblocked_ancestors.should include(parent)
              node.strict_unblocked_ancestors.should include(ancestor)
              node.strict_unblocked_ancestors.should include(global_node)
              node.strict_unblocked_ancestors.size.should == 3
            end

          end

          describe "when there's a security manager" do

            let(:manager) { mock('security manager') }

            before do
              AccessControl.stub!(:get_security_manager).and_return(manager)
              manager.stub!(:restrict_queries=)
              manager.stub!(:verify_access!).and_return(true)
            end

            describe "when the principal has 'change_inheritance_blocking'" do

              it "blocks fine" do
                node.should_receive(:has_permission?).
                  with('change_inheritance_blocking').
                  and_return(true)
                node.block = true
                lambda { node.save! }.should_not raise_exception
              end

            end

            describe "when the principal hasn't 'change_inheritance_blocking'"\
              do
                it "fails to block" do
                  node.should_receive(:has_permission?).
                    with('change_inheritance_blocking').
                    and_return(false)
                  node.block = true
                  lambda do
                    node.save!
                  end.should raise_exception(AccessControl::Unauthorized)
                end
              end

          end

        end

        describe "when unblocking" do

          describe "when there's no security manager" do

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

          describe "when there's a security manager" do

            let(:manager) { mock('security manager') }

            before do
              node.block = true
              node.save!
              AccessControl.stub!(:get_security_manager).and_return(manager)
              manager.stub!(:restrict_queries=)
              manager.stub!(:verify_access!).and_return(true)
            end

            describe "when the principal has 'change_inheritance_blocking'" do
              it "unblocks fine" do
                node.should_receive(:has_permission?).
                  with('change_inheritance_blocking').
                  and_return(true)
                node.block = false
                lambda { node.save! }.should_not raise_exception
              end
            end

            describe "when the principal hasn't 'change_inheritance_blocking'"\
              do
                it "fails to unblock" do
                  node.should_receive(:has_permission?).
                    with('change_inheritance_blocking').
                    and_return(false)
                  node.block = false
                  lambda do
                    node.save!
                  end.should raise_exception(AccessControl::Unauthorized)
                end
              end
          end

        end

      end

    end

  end
end
