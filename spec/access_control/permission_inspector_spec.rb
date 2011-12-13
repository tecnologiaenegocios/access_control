require 'access_control/permission_inspector'

module AccessControl
  describe PermissionInspector do

    let(:node)   { stub('node') }

    def next_role_index
      @roles_count ||= 0
      @roles_count  += 1
    end

    def role_with_permissions(*permissions)
      index = next_role_index
      stub("Role #{index}", :permissions => permissions)
    end

    subject { PermissionInspector.new(node) }

    describe "#current_roles" do
      it "returns the roles that are assigned to the current principal" do
        roles = [role_with_permissions('p1'), role_with_permissions('p2')]
        node.stub(:principal_roles => roles)

        subject.current_roles.should == Set.new(roles)
      end
    end

    describe "#permissions" do
      it "returns the permissions in the node for the current principal" do
        roles = [role_with_permissions('p1', 'p2'),
                 role_with_permissions('p2', 'p3', 'p4')]
        node.stub(:principal_roles => roles)

        subject.permissions.should == Set.new(%w[p1 p2 p3 p4])
      end
    end

    describe "#has_permission?" do
      before do
        roles = [role_with_permissions('p1', 'p2'),
                 role_with_permissions('p2')]

        node.stub(:principal_roles => roles)
      end

      it "returns true when all of the node's roles grant the permission" do
        subject.has_permission?('p2').should be_true
      end

      it "returns true when all of the node's roles grant the permission" do
        subject.has_permission?('p1').should be_true
      end

      it "returns false when none of the node's roles grant the permission" do
        subject.has_permission?('p5').should be_false
      end
    end

  end

end
