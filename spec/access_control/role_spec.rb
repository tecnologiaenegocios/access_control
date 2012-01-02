require 'spec_helper'

module AccessControl
  describe Role do

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
        roles = [Role.store(:name => "foobar")]
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
        roles = [Role.store(:name => "foobar")]
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
      let(:role)      { Role.store(:name => "Foo")  }

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
      let(:role) { Role.store(:name => "Foo")  }

      before do
        principal = stub("Principal", :id => -1)
        role.assign_at(node, principal)
      end

      it "unassigns all roles from the principals given" do
        Role.unassign_all_at(node)
        Role.assigned_at(node).should be_empty
      end
    end


    describe "assignment destruction" do
      let(:assignment) { stub_model(Assignment, :save => true) }
      let(:role)       { Role.new(:name => 'irrelevant') }

      before do
        pending("Still no assignment persistency!")
        role.assignments << assignment
      end

      it "destroys assignments when it is destroyed" do
        assignment.should_receive(:destroy)
        role.destroy
      end

      it "destroys the assignment in a unrestricted block" do
        assignment.should_receive_without_assignment_restriction(:destroy) do
          role.destroy
        end
      end
    end

    it "destroys security policy items when it is destroyed" do
      pending
      role = Role.store(:name => 'the role name')
      SecurityPolicyItem.create!(:role => role,
                                 :permission => 'some permission')
      role.destroy
      SecurityPolicyItem.count.should == 0
    end

    describe "role assignment in principals and nodes" do
      let(:role)       { Role.store(:name => 'role') }
      let(:principal)  { stub_model(Principal) }
      let(:node)       { stub_model(Node) }
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
      let(:role)            { Role.store(:name => 'role') }
      let(:principal)       { stub_model(Principal) }
      let(:other_principal) { stub_model(Principal) }
      let(:node)            { stub_model(Node) }

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

        specify "if principal is unassigned, other principals are still assigned" do
          role.assign_at(node, principal)
          role.unassign_at(node, other_principal)

          role.should be_assigned_at(node, principal)
        end

        specify "when principal is not specified, all nodes are unassigned" do
          role.assign_at(node, principal)
          role.assign_at(node, other_principal)

          role.unassign_at(node)

          role.should_not be_assigned_at(node, principal)
          role.should_not be_assigned_at(node, other_principal)
        end
      end
    end

    context "permissions management" do
      subject { Role.new(:name => "Irrelevant") }

      describe "#add_permissions" do
        it "can be used to add one permissions at a time" do
          subject.add_permissions("p1")
          subject.permissions.should include("p1")
        end

        it "can be used to add many permissions at once" do
          subject.add_permissions("p1", "p2", "p3")
          subject.permissions.should include("p1", "p2", "p3")
        end

        it "doesn't include duplicates" do
          subject.add_permissions("p1", "p1", "p2")
          subject.permissions.count.should == 2
        end

        it "returns only the added permissions" do
          subject.add_permissions("p1", "p2")

          return_value = subject.add_permissions("p1", "p2", "p3")
          return_value.should     include("p3")
          return_value.should_not include("p1", "p2")
        end
      end

      describe "#remove_permissions" do
        it "can be used to remove one permission at time" do
          subject.add_permissions("p1", "p2")
          subject.remove_permissions("p2")

          subject.permissions.should_not include("p2")
        end

        it "can be used to removed many permissions at once" do
          subject.add_permissions("p1", "p2", "p3")
          subject.remove_permissions("p2", "p1")

          subject.permissions.should_not include("p1", "p2")
        end

        it "returns only the removed permissions" do
          subject.add_permissions("p1", "p2", "p3")
          subject.remove_permissions("p1", "p2")

          return_value = subject.remove_permissions("p1", "p2", "p3")
          return_value.should     include("p3")
          return_value.should_not include("p1", "p2")
        end
      end

      context "after a role is persisted" do
        let(:persisted_role) { Role.fetch(subject.id) }

        before do
          subject.add_permissions("p1", "p2")
          subject.persist
        end

        specify "are persisted as well" do
          pending("Still no permission persistency!")
          persisted_role.permissions.should include("p1", "p2")
        end
      end
    end

    describe "scope delegation" do
      delegated_scopes = [:assigned_to, :assigned_at, :for_all_permissions]

      delegated_scopes.each do |delegated_scope|
        it "delegates the scope .#{delegated_scope} to the persistent model" do
          Role.delegated_scopes.should include(delegated_scope)
        end
      end
    end
  end
end
