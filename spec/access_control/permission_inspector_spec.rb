require 'spec_helper'
require 'access_control/permission_inspector'

module AccessControl
  module PermissionInspector
    describe Behavior do

      describe "Role conformance with expected interface" do
        it_has_instance_method(Role, :permissions)
      end

      describe "Node conformance with expected interface" do
        it_has_instance_method(Node, :principal_roles)
        it_has_instance_method(Node, :ancestors)
      end

      let(:parent) { mock('node') }
      let(:node) { mock('node') }
      let(:role1) { stub_model(Role, :permissions => ['permission 1']) }
      let(:role2) { stub_model(Role, :permissions => ['permission 2']) }
      let(:role3) do
        stub_model(Role, :permissions => ['permission 3', 'permission 4'])
      end
      let(:role4) do
        stub_model(Role, :permissions => ['permission 5', 'permission 6'])
      end

      before do
        node.stub(
          :principal_roles => [role1, role2],
          :ancestors => [parent, node]
        )
        parent.stub(
          :principal_roles => [role3, role4],
          :ancestors => [parent]
        )
        node.extend(Behavior)
        parent.extend(Behavior)
      end

      describe "#has_permission?" do
        it "returns true when the user has the required permission" do
          node.has_permission?('permission 6').should be_true
        end

        it "returns false when the user has not the permission" do
          node.has_permission?('permission 7001').should be_false
        end
      end

      describe "#permissions" do
        it "returns the permissions in the node for the current principal" do
          node.permissions.should == Set.new([
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

      describe "#inherited_roles_for_all_principals" do

        describe "Node conformance with expected interface" do
          it_has_instance_method(Node, :global?)
          it_has_instance_method(Node, :strict_unblocked_ancestors)
          it_has_instance_method(Node, :assignments_with_roles, 1)
        end

        describe "Assignment conformance with expected interface" do
          it_has_instance_method(Assignment, :principal_id)
          it_has_instance_method(Assignment, :role_id)
        end

        # We don't depend on Principal's interface explicitly.  We use this
        # only to get nice sequencial unique ids.
        let(:principal1) { stub_model(Principal) }
        let(:principal2) { stub_model(Principal) }

        let(:roles) { [role1, role2, role3, role4] }
        let(:parent) { mock('node', :global? => false) }
        let(:ancestor) { mock('node', :global? => false) }
        let(:global) { mock('node', :global? => true) }
        let(:items) { node.inherited_roles_for_all_principals(roles) }

        before do
          node.stub(:strict_unblocked_ancestors).
            and_return([parent, ancestor, global])
          parent.stub(:assignments_with_roles).and_return([])
          ancestor.stub(:assignments_with_roles).and_return([
            stub(:role_id => role1.id, :principal_id => principal1.id),
            stub(:role_id => role1.id, :principal_id => principal2.id),
            stub(:role_id => role3.id, :principal_id => principal1.id),
          ])
          global.stub(:assignments_with_roles).and_return([
            stub(:role_id => role2.id, :principal_id => principal1.id),
            stub(:role_id => role3.id, :principal_id => principal1.id),
          ])
        end

        it "retrieves the parent assignments with the roles" do
          parent.should_receive(:assignments_with_roles).with(roles).
            and_return([])
          node.inherited_roles_for_all_principals(roles)
        end

        it "retrieves the ancestor assignments with the roles" do
          ancestor.should_receive(:assignments_with_roles).with(roles).
            and_return([])
          node.inherited_roles_for_all_principals(roles)
        end

        it "retrieves the globale assignments with the roles" do
          ancestor.should_receive(:assignments_with_roles).with(roles).
            and_return([])
          node.inherited_roles_for_all_principals(roles)
        end

        it "returns as many items as principals with assignments" do
          items.size.should == 2
        end

        it "returns a hash keyed by principal ids" do
          items.keys.sort.should == [principal1.id, principal2.id].sort
        end

        it "returns values as hashes keyed by role ids, only requested ones" do
          Set.new(items.map{|k, v| v.keys}.flatten).should(
            be_subset(Set.new([role1.id, role2.id, role3.id, role4.id]))
          )
        end

        it "returns a set of 'global' and 'inherited' strings or nil" do
          items[principal1.id][role1.id].should == Set.new(['inherited'])
          items[principal1.id][role2.id].should == Set.new(['global'])
          items[principal1.id][role3.id].should == Set.new(['inherited',
                                                            'global'])
          items[principal2.id][role2.id].should be_nil
          items[principal2.id][role1.id].should == Set.new(['inherited'])
          items[principal2.id][role3.id].should be_nil
        end
      end

    end
  end
end
