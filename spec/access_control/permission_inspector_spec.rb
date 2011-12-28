require 'spec_helper'

module AccessControl
  describe PermissionInspector do

    def stub_node(*roles)
      stubs = roles.extract_options!

      stub("Node", stubs).tap do |node|
        node.stub(:roles => roles)
      end
    end

    def stub_role(*permissions)
      stubs = permissions.extract_options!

      stub("Role", stubs).tap do |role|
        role.stub(:permissions => permissions)
      end
    end

    let(:node_ancestors) { [stub_node, stub_node] }
    let(:node)           { stub_node(:unblocked_ancestors => node_ancestors)}
    let(:principals)     { stub("Current principals") }

    subject { PermissionInspector.new(node, principals) }

    describe "on initialization" do
      it "asks manager for the current principals when none is provided" do
        current_principals = stub
        AccessControl.manager.stub(:principals => current_principals)

        subject = PermissionInspector.new(node)
        subject.principals.should == current_principals
      end

      it "accepts a collection of principals" do
        subject = PermissionInspector.new(node, principals)
        subject.principals.should == principals
      end
    end

    describe "#current_roles" do

      it "returns roles assigned to the principals @ the node's ancestors" do
        roles = [stub_role, stub_role]
        Role.stub(:assigned_to).with(principals, node_ancestors).
          and_return(roles)

        subject.current_roles.should include(*roles)
        subject.current_roles.count.should == roles.count
      end
    end

    describe "#permissions" do
      def set_current_roles_as(roles)
        Role.stub(:assigned_to).with(principals, node_ancestors).
          and_return(roles)
      end

      it "returns the permissions granted by the current roles" do
        roles = [stub_role('p1', 'p2'), stub_role('p2', 'p3', 'p4')]
        set_current_roles_as(roles)

        subject.permissions.should include('p1', 'p2', 'p3', 'p4')
      end
    end

    describe "#has_permission?" do
      def set_current_roles_as(roles)
        Role.stub(:assigned_to).with(principals, node_ancestors).
          and_return(roles)
      end

      before do
        roles = [stub_role('p1', 'p2'), stub_role('p2')]
        set_current_roles_as(roles)
      end

      it "returns true when all of the current roles grant the permission" do
        subject.has_permission?('p2').should be_true
      end

      it "returns true when one of the current roles grant the permission" do
        subject.has_permission?('p1').should be_true
      end

      it "returns false when none of the current roles grant the permission" do
        subject.has_permission?('p5').should be_false
      end
    end

  end

end
