require 'spec_helper'

module AccessControl
  describe PermissionInspector do

    def stub_role(*permissions)
      stubs = permissions.extract_options!

      stub("Role", stubs).tap do |role|
        role.stub(:permissions => permissions)
      end
    end

    def stub_node(stubs = {})
      @node_ids ||= Enumerator.new do |yielder|
        n = 0
        loop { yielder.yield(n += 1) }
      end

      stubs[:persisted?] ||= true
      stubs[:id]         ||= @node_ids.next

      stub("Node", stubs).tap do |node|
        AccessControl.stub(:Node).with(node).and_return(node)
      end
    end

    def stub_securable(stubs = {})
      stubs[:ac_node] ||= stub_node
      stub("Securable", stubs).tap do |securable|
        AccessControl.stub(:Node).with(securable).and_return(stubs[:ac_node])
      end
    end

    let(:node)         { stub_node }
    let(:principals)   { stub("Current principals") }
    let(:securable)    { stub_securable(:ac_node => node) }

    let(:parent_nodes)    { [stub("Parent node")] }

    subject { PermissionInspector.new(node, principals) }

    describe "on initialization" do
      it "accepts a single securable" do
        subject = PermissionInspector.new(securable)
        subject.context.should include_only(node)
      end

      context "when the given securable doesn't have a saved node" do
        before do
          node.stub(:persisted? => false)
          node.stub(:securable).and_return(securable)
          Inheritance.stub(:parent_nodes_of).
            with(securable).and_return(parent_nodes)
        end

        it "asks Inheritance for the node's parents" do
          subject = PermissionInspector.new(securable)
          subject.context.should include_only(*parent_nodes)
        end
      end

      it "accepts a collection of securables" do
        securables = [stub_securable, stub_securable]
        nodes = securables.map(&:ac_node)

        subject = PermissionInspector.new(securables)
        subject.context.should include_only(*nodes)
      end

      it "accepts a single Node" do
        subject = PermissionInspector.new(node)
        subject.context.should include_only(node)
      end

      context "when the given Node wasn't persisted yet" do
        before do
          node.stub(:persisted? => false)
          node.stub(:securable).and_return(securable)
          Inheritance.stub(:parent_nodes_of).
            with(securable).and_return(parent_nodes)
        end

        it "asks Inheritance for the node's parents" do
          subject = PermissionInspector.new(node)
          subject.context.should include_only(*parent_nodes)
        end
      end

      it "accepts a collection of nodes" do
        nodes = [stub_node, stub_node]
        subject = PermissionInspector.new(nodes)

        subject.context.should include_only(*nodes)
      end

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

    def set_current_roles_as(roles)
      Role.stub(:assigned_to) do |*args|
        if args.first == principals && args.second.to_a == [node]
          roles
        else
          raise ArgumentError
        end
      end
    end

    describe "#current_roles" do

      let(:roles) { [stub_role, stub_role] }

      it "returns roles assigned to the principals @ the context" do
        set_current_roles_as(roles)
        subject.current_roles.should include_only(*roles)
      end

      it "isn't searched more than once" do
        Role.should_receive(:assigned_to).exactly(:once).and_return(roles)
        2.times { subject.current_roles }
      end

      it "is a set" do
        set_current_roles_as(roles)
        subject.current_roles.should be_kind_of Set
      end
    end

    describe "#permissions" do
      it "returns the permissions granted by the current roles" do
        roles = [stub_role('p1', 'p2'), stub_role('p2', 'p3', 'p4')]
        set_current_roles_as(roles)

        subject.permissions.should include('p1', 'p2', 'p3', 'p4')
      end
    end

    describe "#has_permission?" do
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

    describe "the role cache" do
      let(:node)       { stub_node }
      let(:principals) { Set[stub("Principals")] }

      let(:instance1) { PermissionInspector.new(node, principals) }
      let(:instance2) { PermissionInspector.new(node, principals) }

      describe "two different instances" do
        specify "with the same parameters have the same roles" do
          Role.stub(:assigned_to)
          instance1.current_roles.should == instance2.current_roles
        end

        specify "won't fetch the same roles twice" do
          Role.should_receive(:assigned_to).exactly(:once)

          instance1.current_roles
          instance2.current_roles
        end

        specify "fetches their roles if given different contexts" do
          other_node = stub_node
          instance2 = PermissionInspector.new(other_node, principals)

          Role.should_receive(:assigned_to).with(principals, Set[node]).once
          Role.should_receive(:assigned_to).with(principals, Set[other_node]).once

          instance1.current_roles
          instance2.current_roles
        end

        specify "fetches their roles if given different principals" do
          other_principals = Set[stub("Other principals")]
          instance2 = PermissionInspector.new(node, other_principals)

          Role.should_receive(:assigned_to).with(principals, Set[node]).once
          Role.should_receive(:assigned_to).with(other_principals, Set[node]).once

          instance1.current_roles
          instance2.current_roles
        end

        context "if PermissionInspector.clear_role_cache is used" do
          before { PermissionInspector.clear_role_cache }

          specify "the roles are fetched again" do
            Role.should_receive(:assigned_to).twice

            instance1.current_roles
            PermissionInspector.clear_role_cache
            instance2.current_roles
          end
        end
      end
    end

  end

end
