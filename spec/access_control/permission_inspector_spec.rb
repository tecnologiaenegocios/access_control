require 'access_control/permission_inspector'
require 'active_support'

module AccessControl
  describe PermissionInspector do

    let(:parent_node) { stub_node('parent node') }
    let(:node)        { stub_node('node', :ancestors => parent_node) }

    def stub_node(name, *args)
      properties = args.extract_options!

      ancestors = Set.new Array(properties[:ancestors])
      roles     = Set.new Array(properties[:roles])

      stub(name, *args).tap do |node|
        ancestors.add(node)
        node.stub(:unblocked_ancestors => ancestors)
        node.stub(:principal_roles     => roles)
      end
    end

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

        subject.current_roles.should include *roles
      end

      it "returns roles that are assigned to the node's ancestors principal" do
        roles = [role_with_permissions('p1'), role_with_permissions('p2')]
        parent_node.stub(:principal_roles => roles)

        subject.current_roles.should include *roles
      end
    end

    describe "#permissions" do
      it "returns the permissions in the node for the current principal" do
        roles = [role_with_permissions('p1', 'p2'),
                 role_with_permissions('p2', 'p3', 'p4')]
        node.stub(:principal_roles => roles)

        subject.permissions.should include('p1', 'p2', 'p3', 'p4')
      end

      it "returns the permissions in ancestors nodes" do
        roles = [role_with_permissions('p1', 'p2'),
                 role_with_permissions('p2', 'p3', 'p4')]
        parent_node.stub(:principal_roles => roles)

        subject.permissions.should include('p1', 'p2', 'p3', 'p4')
      end
    end

    describe "#has_permission?" do
      before do
        roles = [role_with_permissions('p1', 'p2'),
                 role_with_permissions('p2')]
        node.stub(:principal_roles => roles)

        parent_roles = [role_with_permissions('a1', 'a2'),
                 role_with_permissions('a2')]
        parent_node.stub(:principal_roles => parent_roles)
      end

      it "returns true when all of the node's roles grant the permission" do
        subject.has_permission?('p2').should be_true
      end

      it "returns true when one of the node's roles grant the permission" do
        subject.has_permission?('p1').should be_true
      end

      it "returns true when all of the ancestor roles grant the permission" do
        subject.has_permission?('a2').should be_true
      end

      it "returns true when one of the ancestor roles grant the permission" do
        subject.has_permission?('a1').should be_true
      end

      it "returns false when none of the node's roles grant the permission" do
        subject.has_permission?('p5').should be_false
      end
    end

  end

end
