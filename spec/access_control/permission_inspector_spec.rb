require 'spec_helper'
require 'access_control/assignment'
require 'access_control/node'
require 'access_control/permission_inspector'
require 'access_control/role'

module AccessControl
  describe PermissionInspector do

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

    let(:inspector) { PermissionInspector.new(node) }

    before do
      node.stub(
        :principal_roles => [role1, role2],
        :unblocked_ancestors => [parent, node]
      )
      parent.stub(
        :principal_roles => [role3, role4],
        :unblocked_ancestors => [parent]
      )
    end

    describe "#has_permission?" do
      it "returns true when the user has the required permission" do
        inspector.has_permission?('permission 6').should be_true
      end

      it "returns false when the user has not the permission" do
        inspector.has_permission?('permission 7001').should be_false
      end
    end

    describe "#permissions" do
      it "returns the permissions in the node for the current principal" do
        inspector.permissions.should == Set.new([
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
        inspector.current_roles.should == Set.new([role1, role2, role3, role4])
        PermissionInspector.new(parent).current_roles.
          should == Set.new([role3, role4])
      end
    end
  end

end
