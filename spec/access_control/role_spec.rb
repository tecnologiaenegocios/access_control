require 'spec_helper'

module AccessControl
  describe Role do

    describe ".assign_all" do
      let(:combination) do
        Array.new.tap do |combination|
          combination.stub(:nodes=)
          combination.stub(:principals=)
          combination.stub(:roles=)
          combination.stub(:skip_existing_assigments=)
        end
      end

      let(:roles)      { stub("Roles collection")      }
      let(:nodes)      { stub("Nodes collection")      }
      let(:principals) { stub("Principals collection") }

      it "sets up the roles of the combination using its parameter" do
        combination.should_receive(:roles=).with(roles)
        Role.assign_all(roles, principals, nodes, combination)
      end

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:nodes=).with(nodes)
        Role.assign_all(roles, principals, nodes, combination)
      end

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:principals=).with(principals)
        Role.assign_all(roles, principals, nodes, combination)
      end

      it "sets the combination's 'skip_existing_assigments' to true" do
        combination.should_receive(:skip_existing_assigments=).with(true)
        Role.assign_all(roles, principals, nodes, combination)
      end

      it "saves each returned assignment" do
        new_assignment = stub("New assignment")
        combination << new_assignment

        new_assignment.should_receive(:persist!)
        Role.assign_all(roles, principals, nodes, combination)
      end
    end

    describe ".unassign_all" do
      let(:combination) do
        Array.new.tap do |combination|
          combination.stub(:nodes=)
          combination.stub(:principals=)
          combination.stub(:roles=)
          combination.stub(:only_existing_assigments=)
        end
      end

      let(:roles)      { stub("Roles collection")      }
      let(:nodes)      { stub("Nodes collection")      }
      let(:principals) { stub("Principals collection") }

      it "sets up the roles of the combination using its parameter" do
        combination.should_receive(:roles=).with(roles)
        Role.unassign_all(roles, principals, nodes, combination)
      end

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:nodes=).with(nodes)
        Role.unassign_all(roles, principals, nodes, combination)
      end

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:principals=).with(principals)
        Role.unassign_all(roles, principals, nodes, combination)
      end

      it "sets the combination's 'only_existing_assigments' to true" do
        combination.should_receive(:only_existing_assigments=).with(true)
        Role.unassign_all(roles, principals, nodes, combination)
      end

      it "destroys each returned assignment" do
        new_assignment = stub("New assignment")
        combination << new_assignment

        new_assignment.should_receive(:destroy)
        Role.unassign_all(roles, principals, nodes, combination)
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

    describe "role assignment in principals and nodes" do
      let(:role)       { Role.new(:name => 'role') }
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

      it "assigns using ids" do
        role.assign_to(principal.id, node.id)
        role.should be_assigned_to(principal, node)
      end

      it "verifies using ids" do
        role.assign_to(principal, node)
        role.should be_assigned_to(principal.id, node.id)
      end

      it "doesn't cause trouble if assigned more than once" do
        role.assign_to(principal, node)
        role.assign_to(principal, node)
      end

      specify "are persisted when the role is saved" do
        role.assign_to(principal, node)
        role.persist!

        persisted_role = Role.fetch(role.id)
        persisted_role.should be_assigned_to(principal, node)
      end

      specify "aren't saved more than once" do
        role.assign_to(principal, node)
        role.persist!
        lambda { role.persist! }.should_not raise_exception
      end

      describe "unassignment" do
        it "unassigns a role from a principal in the given node" do
          role.assign_to(principal, node)
          role.unassign_from(principal, node)

          role.should_not be_assigned_to(principal, node)
        end

        it "unassigns a role using a principal id and node id" do
          role.assign_to(principal, node)
          role.unassign_from(principal.id, node.id)

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

        specify "when node is not specified, unassigns all by principal id" do
          role.assign_to(principal, node)
          role.assign_to(principal, other_node)

          role.unassign_from(principal.id)

          role.should_not be_assigned_to(principal, node)
          role.should_not be_assigned_to(principal, other_node)
        end
      end

      context "within a persisted role" do
        specify "assignments are persisted" do
          role.persist!
          role.assign_to(principal, node)

          persisted_role = Role.fetch(role.id)
          persisted_role.should be_assigned_to(principal, node)
        end
      end
    end

    describe "role assignment in nodes and principals" do
      let(:role)            { Role.new(:name => 'role') }
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

      it "assigns using ids" do
        role.assign_at(node.id, principal.id)
        role.should be_assigned_at(node, principal)
      end

      it "verifies using ids" do
        role.assign_at(node, principal)
        role.should be_assigned_at(node.id, principal.id)
      end

      it "doesn't cause trouble if assigned more than once" do
        role.assign_at(node, principal)
        role.assign_at(node, principal)
      end

      specify "are persisted when the role is saved" do
        role.assign_at(node, principal)
        role.persist!

        persisted_role = Role.fetch(role.id)
        persisted_role.should be_assigned_at(node, principal)
      end

      specify "aren't saved more than once" do
        role.assign_at(node, principal)
        role.persist!
        lambda { role.persist! }.should_not raise_exception
      end

      describe "unassignment" do
        it "unassigns a role from a principal in the given node" do
          role.assign_at(node, principal)
          role.unassign_at(node, principal)

          role.should_not be_assigned_at(node, principal)
        end

        it "unassigns a role using a principal id and node id" do
          role.assign_at(node, principal)
          role.unassign_at(node.id, principal.id)

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

        specify "when principal is not specified, unassigns all by node id" do
          role.assign_at(node, principal)
          role.assign_at(node, other_principal)

          role.unassign_at(node.id)

          role.should_not be_assigned_at(node, principal)
          role.should_not be_assigned_at(node, other_principal)
        end
      end

      context "within a persisted role" do
        specify "are persisted" do
          role.persist!
          role.assign_at(node, principal)

          persisted_role = Role.fetch(role.id)
          persisted_role.should be_assigned_at(node, principal)
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

        context "when the role is new" do
          it "persists added permissions when the role is saved" do
            subject.add_permissions('p1', 'p2')
            subject.persist!

            persisted_role = Role.fetch(subject.id)
            persisted_role.permissions.to_a.should include_only('p1', 'p2')
          end
        end

        context "when the role is already persisted" do
          it "persists the permissions at the moment they are added" do
            subject.add_permissions('p1')
            subject.persist!
            subject.add_permissions('p2')

            persisted_role = Role.fetch(subject.id)
            persisted_role.permissions.to_a.should include_only('p1', 'p2')
          end
        end
      end

      describe "#del_permissions" do
        it "can be used to remove one permission at time" do
          subject.add_permissions("p1", "p2")
          subject.del_permissions("p2")

          subject.permissions.should_not include("p2")
        end

        it "can be used to removed many permissions at once" do
          subject.add_permissions("p1", "p2", "p3")
          subject.del_permissions("p2", "p1")

          subject.permissions.should_not include("p1", "p2")
        end

        it "returns only the removed permissions" do
          subject.add_permissions("p1", "p2", "p3")
          subject.del_permissions("p1", "p2")

          return_value = subject.del_permissions("p1", "p2", "p3")
          return_value.should     include("p3")
          return_value.should_not include("p1", "p2")
        end

        context "when the role is new" do
          it "persists removal of permissions when the role is saved" do
            subject.add_permissions("p1", "p2", "p3")
            subject.del_permissions('p1', 'p2')
            subject.persist!

            persisted_role = Role.fetch(subject.id)
            persisted_role.permissions.to_a.should include_only('p3')
          end
        end

        context "when the role is already persisted" do
          it "removes the permissions at the moment they are added" do
            subject.add_permissions("p1", "p2", "p3")
            subject.persist!
            subject.del_permissions('p1', 'p2')

            persisted_role = Role.fetch(subject.id)
            persisted_role.permissions.to_a.should include_only('p3')
          end
        end
      end
    end

    context "when role is removed" do
      let(:role)      { Role.store(:name => 'Irrelevant') }
      let(:principal) { stub('principal', :id => 1) }
      let(:node)      { stub('node',      :id => 1) }

      before do
        role.add_permissions('p1', 'p2')
        role.assign_to(principal, node)
        role.destroy
      end

      it "reports itself having no assignments" do
        role.should_not be_assigned_to(principal, node)
      end

      it "removes its assignments" do
        Assignment.with_roles(role.id).should be_empty
      end

      it "removes its permissions" do
        SecurityPolicyItem.find_all_by_role_id(role.id).should be_empty
      end
    end

    describe "subset delegation" do
      delegated_subsets = [:assigned_to, :assigned_at, :for_all_permissions,
                           :default, :with_names_in, :local_assignables,
                           :global_assignables]

      delegated_subsets.each do |delegated_subset|
        it "delegates the subset .#{delegated_subset} to the persistent model" do
          Role.delegated_subsets.should include(delegated_subset)
        end
      end
    end
  end
end
