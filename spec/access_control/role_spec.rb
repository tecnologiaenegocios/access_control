require 'spec_helper'
require 'access_control/role'

module AccessControl
  describe Role do

    let(:manager) { Manager.new }

    def should_receive_without_assignment_restriction(tested_mock, method_name)
      manager = stub('manager')
      AccessControl.stub(:manager).and_return(manager)

      tested_mock.should_receive(:_before_block).ordered
      tested_mock.should_receive(method_name).ordered
      tested_mock.should_receive(:_after_block).ordered

      manager.define_singleton_method(:without_assignment_restriction) do |&b|
        if block_given?
          tested_mock._before_block
          b.call
          tested_mock._after_block
        end
      end

      yield
    end

    before do
      AccessControl.stub(:manager).and_return(manager)
    end

    it "validates presence of name" do
      Role.new.should have(1).error_on(:name)
    end

    it "validates uniqueness of name" do
      Role.create!(:name => 'the role name')
      Role.new(:name => 'the role name').should have(1).error_on(:name)
    end

    it "can be created with valid attributes" do
      Role.create!(:name => 'the role name')
    end

    it "is extended with AccessControl::Ids" do
      Role.singleton_class.should include(AccessControl::Ids)
    end

    describe ".assigned_to" do
      let(:principal) { stub("Principal", :id => 123) }
      let(:node)      { stub("Node",      :id => -1)  }
      let(:role)      { Role.create!(:name => "Foo")  }

      before do
        AccessControl.stub(:Node).with(node).and_return(node)
        role.assign_to(principal, node)
      end

      it "includes roles that were assigned to the given principal" do
        Role.assigned_to(principal).should include role
      end

      it "doesn't include roles that not assigned to the given principal" do
        other_role = Role.create!(:name => "Bar")
        Role.assigned_to(principal).should_not include other_role
      end

      context "when a node is provided" do
        it "includes roles assigned to the principal on the node" do
          Role.assigned_to(principal, node).should include role
        end

        it "doesn't include roles assigned to the principal on other nodes" do
          other_node = stub("Other node", :id => -2)
          Role.assigned_to(principal, other_node).should_not include role
        end
      end
    end

    describe ".assigned_at" do
      let(:node)      { stub("Node",      :id => -1) }
      let(:principal) { stub("Principal", :id => -1) }
      let(:role)      { Role.create!(:name => "Foo") }

      before do
        AccessControl.stub(:Node).with(node).and_return(node)

        role.assign_to(principal, node)
      end

      it "includes roles that were assigned on the given node" do
        Role.assigned_at(node).should include role
      end

      it "doesn't include roles that not assigned at the given node" do
        other_role = Role.create!(:name => "Bar")
        Role.assigned_at(node).should_not include other_role
      end

      context "when a principal is provided" do
        it "includes roles assigned on the node to the principal" do
          Role.assigned_at(node, principal).should include role
        end

        it "doesn't include roles assigned on the node to other principals" do
          other_principal = stub("Other principal", :id => -2)
          Role.assigned_at(node, other_principal).should_not include role
        end
      end
    end

    describe ".assign_all" do
      let(:combination) do
        Array.new.tap do |combination|
          combination.stub(:nodes=)
          combination.stub(:principals=)
          combination.stub(:role_ids=)
          combination.stub(:skip_existing_assigments=)
        end
      end

      let(:nodes)      { stub("Nodes collection")      }
      let(:principals) { stub("Principals collection") }

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:nodes=).with(nodes)
        Role.assign_all(principals, nodes, combination)
      end

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:principals=).with(principals)
        Role.assign_all(principals, nodes, combination)
      end

      it "sets the combination's 'role_ids' as being all role ids" do
        roles = [Role.create!(:name => "foobar")]
        combination.should_receive(:role_ids=).with(roles.map(&:id))

        Role.assign_all(principals, nodes, combination)
      end

      it "sets the combination's 'skip_existing_assigments' to true" do
        combination.should_receive(:skip_existing_assigments=).with(true)
        Role.assign_all(principals, nodes, combination)
      end

      it "saves each returned assignment" do
        new_assignment = stub("New assignment")
        combination << new_assignment

        new_assignment.should_receive(:save!)
        Role.assign_all(principals, nodes, combination)
      end
    end

    describe ".unassign_all" do
      let(:combination) do
        Array.new.tap do |combination|
          combination.stub(:nodes=)
          combination.stub(:principals=)
          combination.stub(:role_ids=)
          combination.stub(:only_existing_assigments=)
        end
      end

      let(:nodes)      { stub("Nodes collection")      }
      let(:principals) { stub("Principals collection") }

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:nodes=).with(nodes)
        Role.unassign_all(principals, nodes, combination)
      end

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:principals=).with(principals)
        Role.unassign_all(principals, nodes, combination)
      end

      it "sets the combination's 'role_ids' as being all role ids" do
        roles = [Role.create!(:name => "foobar")]
        combination.should_receive(:role_ids=).with(roles.map(&:id))

        Role.unassign_all(principals, nodes, combination)
      end

      it "sets the combination's 'only_existing_assigments' to true" do
        combination.should_receive(:only_existing_assigments=).with(true)
        Role.unassign_all(principals, nodes, combination)
      end

      it "destroys each returned assignment" do
        # Assignment destruction itself will care about restriction.
        new_assignment = stub("New assignment")
        combination << new_assignment

        new_assignment.should_receive(:destroy)
        Role.unassign_all(principals, nodes, combination)
      end
    end

    describe ".unassign_all_from" do
      let(:principal) { stub("Principal", :id => 123) }
      let(:role)      { Role.create!(:name => "Foo")  }

      before do
        node = stub("Node", :id => -1)
        role.assign_to(principal, node)
      end

      it "unassigns all roles from the principals given" do
        Role.unassign_all_from(principal)
        Role.assigned_to(principal).should be_empty
      end
    end

    describe ".unassign_all_at" do
      let(:node) { stub("Node", :id => 123) }
      let(:role) { Role.create!(:name => "Foo")  }

      before do
        principal = stub("Principal", :id => -1)
        role.assign_at(node, principal)
      end

      it "unassigns all roles from the principals given" do
        Role.unassign_all_at(node)
        Role.assigned_at(node).should be_empty
      end
    end

    describe ".default" do
      let(:roles_names) { ["owner"] }
      before do
        AccessControl.config.stub(:default_roles => roles_names)
      end

      it "contains roles whose name is in config.default_roles" do
        role = Role.create!(:name => "owner")
        Role.default.should include role
      end

      it "doesn't contain roles whose name isn't in config.default_roles" do
        role = Role.create!(:name => "user")
        Role.default.should_not include role
      end

      it "doesn't blow up when config returns a Set with multiple values" do
        AccessControl.config.stub(:default_roles => Set["owner", "manager"])
        role = Role.create!(:name => "owner")

        accessing_the_results = lambda { Role.default.include?(role) }
        accessing_the_results.should_not raise_error
      end
    end

    describe ".with_names" do
      let!(:role) { Role.create!(:name => "foo") }

      context "for string arguments" do
        it "returns roles whose name is the argument" do
          Role.with_names_in("foo").should include role
        end

        it "doesn't return roles whose name isn't argument" do
          Role.with_names_in("bar").should_not include role
        end
      end

      context "for set arguments" do
        it "returns roles whose name is included in the set" do
          names = Set["foo", "bar"]
          Role.with_names_in(names).should include role
        end

        it "doesn't return roles whose name isn't included in the set" do
          names = Set["baz", "bar"]
          Role.with_names_in(names).should_not include role
        end
      end
    end

    describe "assignment destruction" do

      let(:assignment) do
        stub_model(Assignment, :[]= => true, :save => true)
      end

      let(:role) do
        Role.new(:name => 'the role name')
      end

      before do
        Object.const_set('TestPoint', stub('testpoint'))
        role.assignments << assignment
      end

      after do
        Object.send(:remove_const, 'TestPoint')
      end

      it "destroys assignments when it is destroyed" do
        assignment.should_receive(:destroy)
        role.destroy
      end

      it "destroys the assignment in a unrestricted block" do
        TestPoint.should_receive(:before_yield).ordered
        TestPoint.should_receive(:on_destroy).ordered
        TestPoint.should_receive(:after_yield).ordered
        manager.instance_eval do
          def without_assignment_restriction
            TestPoint.before_yield
            yield
            TestPoint.after_yield
          end
        end
        assignment.instance_eval do
          def destroy
            TestPoint.on_destroy
          end
        end
        role.destroy
      end

    end

    it "destroys security policy items when it is destroyed" do
      role = Role.create!(:name => 'the role name')
      SecurityPolicyItem.create!(:role => role,
                                 :permission => 'some permission')
      role.destroy
      SecurityPolicyItem.count.should == 0
    end

    describe ".local_assignables" do

      it "returns only roles with local = true" do
        r1 = Role.create!(:name => 'local unassignable', :local => false)
        r2 = Role.create!(:name => 'local assignable', :local => true)
        Role.local_assignables.should == [r2]
      end

    end

    describe ".global_assignables" do

      it "returns only roles with global = true" do
        r1 = Role.create!(:name => 'global unassignable', :global => false)
        r2 = Role.create!(:name => 'global assignable', :global => true)
        Role.global_assignables.should == [r2]
      end

    end

    describe ".for_permission" do
      let(:item) { stub('security policy item', :role_id => 'some id') }
      let(:proxy) { stub('security policy items proxy') }
      before do
        SecurityPolicyItem.stub(:with_permission).and_return(proxy)
        proxy.stub(:role_ids).and_return('role ids')
      end

      it "gets all relevant security policy items" do
        SecurityPolicyItem.should_receive(:with_permission).
          with('some permission').and_return(proxy)
        Role.for_permission('some permission')
      end

      it "gets all role ids from them" do
        proxy.should_receive(:role_ids)
        Role.for_permission('some permission')
      end

      it "returns a condition over the ids" do
        Role.for_permission('some permission').proxy_options.should == {
          :conditions => { :id => 'role ids' }
        }
      end
    end

    describe "#permissions" do
      subject { Role.new }
      let(:permissions) { ['other permission', 'some permission'] }

      before do
        subject.security_policy_items = permissions.map do |perm|
          stub_model(SecurityPolicyItem, :permission => perm)
        end
      end

      it "returns the permissions from its security policy items" do
        subject.permissions.should include(*permissions)
      end

      it "doesn't return duplicated permissions" do
        subject.permissions.length.should == permissions.length
      end
    end

    describe "role assignment in principals and nodes" do
      let(:role) { Role.create!(:name => 'role') }
      let(:principal) { stub_model(Principal) }
      let(:node) { stub_model(Node) }
      let(:other_node) { stub_model(Node) }

      specify "roles are not initially assigned" do
        role.should_not be_assigned_to(principal, node)
      end

      it "assigns a role to a principal in the given node" do
        role.assign_to(principal, node)
        role.should be_assigned_to(principal, node)
      end

      it "doesn't cause trouble if assigned more than once" do
        role.assign_to(principal, node)
        role.assign_to(principal, node)
      end

      describe "unassignment" do
        it "unassigns a role from a principal in the given node" do
          role.assign_to(principal, node)
          role.unassign_from(principal, node)

          role.should_not be_assigned_to(principal, node)
        end

        specify "if node is not assigned, doesn't cause error" do
          role.unassign_from(principal, other_node)
        end

        specify "if node is not assigned, other nodes are still assigned" do
          role.assign_to(principal, node)
          role.unassign_from(principal, other_node)

          role.should be_assigned_to(principal, node)
        end

        specify "when node is not specified, all nodes are unassigned" do
          role.assign_to(principal, node)
          role.assign_to(principal, other_node)

          role.unassign_from(principal)

          role.should_not be_assigned_to(principal, node)
          role.should_not be_assigned_to(principal, other_node)
        end
      end
    end

    describe "role assignment in nodes and principals" do
      let(:role) { Role.create!(:name => 'role') }
      let(:principal) { stub_model(Principal) }
      let(:other_principal) { stub_model(Principal) }
      let(:node) { stub_model(Node) }

      specify "roles are not initially assigned" do
        role.should_not be_assigned_at(node, principal)
      end

      it "assigns a role in the given node to a principal" do
        role.assign_at(node, principal)
        role.should be_assigned_at(node, principal)
      end

      it "doesn't cause trouble if assigned more than once" do
        role.assign_at(node, principal)
        role.assign_at(node, principal)
      end

      describe "unassignment" do
        it "unassigns a role from a principal in the given node" do
          role.assign_at(node, principal)
          role.unassign_at(node, principal)

          role.should_not be_assigned_at(node, principal)
        end

        specify "if principal is not assigned, doesn't cause error" do
          role.unassign_at(node, other_principal)
        end

        specify "if node is not assigned, other nodes are still assigned" do
          role.assign_at(node, principal)
          role.unassign_at(node, other_principal)

          role.should be_assigned_at(node, principal)
        end

        specify "when node is not specified, all nodes are unassigned" do
          role.assign_at(node, principal)
          role.assign_at(node, other_principal)

          role.unassign_at(node)

          role.should_not be_assigned_at(node, principal)
          role.should_not be_assigned_at(node, other_principal)
        end
      end
    end

    describe "#assign_permission" do

      let(:association_proxy) { stub('association proxy') }
      let(:permission) { 'a permission' }
      let(:role) { Role.new }

      before do
        role.stub(:security_policy_items).and_return(association_proxy)
        association_proxy.stub(:find_by_permission).and_return(nil)
        association_proxy.stub(:create!)
      end

      def make_assignment
        role.assign_permission(permission)
      end

      it "finds the permission at first" do
        association_proxy.should_receive(:find_by_permission).
          with(permission).and_return(nil)
        make_assignment
      end

      context "the permission doesn't exist" do
        it "creates a new security policy item from the assoc. proxy" do
          association_proxy.should_receive(:create!).with(
            :permission => permission
          )
          make_assignment
        end
      end

      context "the permission already exists" do
        let(:item) { stub('security policy item') }

        before do
          association_proxy.stub(:find_by_permission).and_return(item)
        end

        it "does nothing" do
          association_proxy.should_not_receive(:create!)
          make_assignment
        end
      end

    end

  end
end
