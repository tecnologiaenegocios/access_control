require 'spec_helper'

module AccessControl
  describe Role do

    def ids
      @ids ||= 1.to_enum(:upto, Float::INFINITY)
    end

    def stub_node(stubs = {})
      id = stubs[:id]      ||= ids.next
      stubs[:securable_id] ||= ids.next

      stub("Node #{id}", stubs).tap do |node|
        AccessControl.stub(:Node).with(node).
          and_return(node)
      end
    end

    def stub_principal(stubs = {})
      id = stubs[:id]    ||= ids.next
      stubs[:subject_id] ||= ids.next

      stub("Principal #{id}", stubs).tap do |principal|
        AccessControl.stub(:Principal).with(principal).
          and_return(principal)
      end
    end

    def stub_permission(name = nil)
      name ||= "Permission '#{ids.next}'"

      stub(name).tap do |permission|
        permission.stub(:name => name)
        Registry.stub(:[]).with(name).and_return(permission)
      end
    end

    describe ".assign_default_at" do
      let(:securable_class) { Class.new Sequel::Model(:records) }

      let!(:securable) { securable_class.create }
      let(:node)   { Node.store(:securable_class => securable_class,
                                :securable_id    => securable.id) }
      before { securable.stub(:ac_node => node) }


      let(:role1) { Role.store(:name => 'default') }
      let(:role2) { Role.store(:name => 'other_default') }

      let(:principals) { 2.times.map { stub_principal } }

      let(:config)  { stub('configuration') }

      let!(:role3) { Role.store(:name => 'non_default') }

      before do
        AccessControl.stub(:config).and_return(config)
        config.stub(:default_roles).and_return([role1.name, role2.name])
      end

      it "accepts a securable instead of a node" do
        Role.assign_default_at(securable, principals)

        principals.each do |principal|
          role1.should be_assigned_to(principal, node)
          role2.should be_assigned_to(principal, node)
        end
      end

      it "accepts subjects instead of principals" do
        subjects = principals.map do |principal|
          subject = stub("Subject")
          AccessControl.stub(:Principal).with(subject).
            and_return(principal)
          subject
        end

        Role.assign_default_at(node, subjects)

        principals.each do |principal|
          role1.should be_assigned_to(principal, node)
          role2.should be_assigned_to(principal, node)
        end
      end

      it "assigns default roles to the current principals in the given node" do
        Role.assign_default_at(node, principals)

        principals.each do |principal|
          role1.should be_assigned_to(principal, node)
          role2.should be_assigned_to(principal, node)
        end
      end

      it "doesn't assign non default roles" do
        Role.assign_default_at(node, principals)

        principals.each do |principal|
          role3.should_not be_assigned_to(principal, node)
        end
      end
    end

    describe ".assign_all" do
      let(:combination) do
        Array.new.tap do |combination|
          combination.stub(:nodes=)
          combination.stub(:principals=)
          combination.stub(:roles=)
          combination.stub(:skip_existing_assigments=)
        end
      end

      let(:roles)      { stub("Roles collection") }
      let(:nodes)      { [stub_node]              }
      let(:principals) { [stub_principal]         }

      it "sets up the roles of the combination using its parameter" do
        combination.should_receive(:roles=).with(roles)
        Role.assign_all(roles, principals, nodes, combination)
      end

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:nodes=).with(nodes)
        Role.assign_all(roles, principals, nodes, combination)
      end

      it "sets up the principals of the combination using its parameter" do
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

      let(:roles)      { stub("Roles collection") }
      let(:nodes)      { [stub_node]              }
      let(:principals) { [stub_principal]         }

      it "sets up the roles of the combination using its parameter" do
        combination.should_receive(:roles=).with(roles)
        Role.unassign_all(roles, principals, nodes, combination)
      end

      it "sets up the nodes of the combination using its parameter" do
        combination.should_receive(:nodes=).with(nodes)
        Role.unassign_all(roles, principals, nodes, combination)
      end

      it "sets up the principals of the combination using its parameter" do
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
      let(:principal) { stub_principal }
      let(:role)      { Role.store(:name => "Foo")  }

      before do
        node = stub_node
        role.assign_to(principal, node)
      end

      it "unassigns all roles from the principals given" do
        Role.unassign_all_from(principal)
        Role.assigned_to(principal).should be_empty
      end
    end

    describe ".unassign_all_at" do
      let(:node) { stub_node }
      let(:role) { Role.store(:name => "Foo") }

      before do
        principal = stub_principal
        role.assign_at(node, principal)
      end

      it "unassigns all roles from the principals given" do
        Role.unassign_all_at(node)
        Role.assigned_at(node).should be_empty
      end
    end

    describe "role assignment in principals and nodes" do
      let(:role)       { Role.new(:name => 'role') }
      let(:principal)  { stub_principal }
      let(:node)       { stub_node }
      let(:other_node) { stub_node }

      specify "roles are not initially assigned" do
        role.should_not be_assigned_to(principal, node)
      end

      it "assigns a role to a principal in the given node" do
        role.assign_to(principal, node)
        role.should be_assigned_to(principal, node)
      end

      it "accepts a securable instead of a node" do
        securable = stub("Securable")
        AccessControl.stub(:Node).with(securable).and_return(node)

        role.assign_to(principal, securable)
        role.should be_assigned_to(principal, node)
      end

      it "accepts a subject instead of a principal" do
        subject = stub("Subject")
        AccessControl.stub(:Principal).with(subject).
          and_return(principal)

        role.assign_to(subject, node)
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

      it "can assign to principal at global node" do
        role.globally_assign_to(principal)
        role.should be_assigned_to(principal, AccessControl.global_node)
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

        it "can unassign from principal at global node" do
          role.assign_to(principal, AccessControl.global_node)
          role.globally_unassign_from(principal)

          role.should_not be_assigned_to(principal, AccessControl.global_node)
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
      let(:principal)       { stub_principal }
      let(:other_principal) { stub_principal }
      let(:node)            { stub_node }

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

      it "accepts a securable instead of a node" do
        securable = stub("Securable")
        AccessControl.stub(:Node).with(securable).and_return(node)

        role.assign_at(securable, principal)
        role.should be_assigned_at(node, principal)
      end

      it "accepts a subject instead of a principal" do
        subject = stub("Subject")
        AccessControl.stub(:Principal).with(subject).
          and_return(principal)

        role.assign_at(node, subject)
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

        it "accepts a securable instead of a node" do
          securable = stub("Securable")
          AccessControl.stub(:Node).with(securable).and_return(node)

          role.assign_at(node, principal)
          role.unassign_at(securable, principal)

          role.should_not be_assigned_at(node, principal)
        end

        it "accepts a subject instead of a principal" do
          subject = stub("Subject")
          AccessControl.stub(:Principal).with(subject).
            and_return(principal)

          role.assign_at(node, principal)
          role.unassign_at(node, subject)

          role.should_not be_assigned_at(node, principal)
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

    describe "assignment-related predicate methods" do
      let(:node)       { stub_node      }
      let(:child_node) { stub_node      }
      let(:principal)  { stub_principal }

      let!(:local_assignment) do
        Assignment.store(:role_id => subject.id, :node_id => node.id,
                         :principal_id => principal.id)
      end

      subject { Role.store(:name => "Irrelevant") }

      describe "#assigned_to?" do
        it "returns true if the role was directly assigned" do
          subject.should be_assigned_to(principal, node)
        end

        it "accepts a securable instead of a node" do
          securable = stub("Securable")
          AccessControl.stub(:Node).with(securable).and_return(node)

          subject.should be_assigned_to(principal, securable)
        end

        it "accepts a subject instead of a principal" do
          subj = stub("Subject")
          AccessControl.stub(:Principal).with(subj).
            and_return(principal)

          subject.should be_assigned_to(subj, node)
        end

        it "returns true if the role was inherited" do
          local_assignment.propagate_to(child_node)
          subject.should be_assigned_to(principal, child_node)
        end
      end

      describe "#globally_assign_to?" do
        before do
          AccessControl.stub(:Node).with(AccessControl.global_node).
            and_return(AccessControl.global_node)
        end

        it "returns false if the role was not assigned at the global node" do
          subject.globally_unassign_from(principal)
          subject.should_not be_globally_assigned_to(principal)
        end

        it "returns true if the role was directly assigned at the global node" do
          subject.globally_assign_to(principal)
          subject.should be_globally_assigned_to(principal)
        end

        it "accepts a subject instead of a principal" do
          subj = stub("Subject")
          AccessControl.stub(:Principal).with(subj).
            and_return(principal)
          subject.globally_assign_to(principal)

          subject.should be_globally_assigned_to(subj)
        end
      end

      describe "#locally_assigned_to?" do
        it "returns true if the role was directly assigned" do
          subject.should be_locally_assigned_to(principal, node)
        end

        it "accepts a securable instead of a node" do
          securable = stub("Securable")
          AccessControl.stub(:Node).with(securable).and_return(node)

          subject.should be_locally_assigned_to(principal, securable)
        end

        it "accepts a subject instead of a principal" do
          subj = stub("Subject")
          AccessControl.stub(:Principal).with(subj).
            and_return(principal)

          subject.should be_locally_assigned_to(subj, node)
        end

        it "returns false if the role was inherited" do
          local_assignment.propagate_to(child_node)
          subject.should_not be_locally_assigned_to(principal, child_node)
        end
      end

      describe "#assigned_at?" do
        it "returns true if the role was directly assigned" do
          subject.should be_assigned_at(node, principal)
        end

        it "accepts a securable instead of a node" do
          securable = stub("Securable")
          AccessControl.stub(:Node).with(securable).and_return(node)

          subject.should be_assigned_at(securable, principal)
        end

        it "accepts a subject instead of a principal" do
          subj = stub("Subject")
          AccessControl.stub(:Principal).with(subj).
            and_return(principal)

          subject.should be_assigned_at(node, subj)
        end

        it "returns true if the role was inherited" do
          local_assignment.propagate_to(child_node)
          subject.should be_assigned_at(child_node, principal)
        end
      end

      describe "#locally_assigned_at?" do
        it "returns true if the role was directly assigned" do
          subject.should be_locally_assigned_at(node, principal)
        end

        it "accepts a securable instead of a node" do
          securable = stub("Securable")
          AccessControl.stub(:Node).with(securable).and_return(node)

          subject.should be_locally_assigned_at(securable, principal)
        end

        it "accepts a subject instead of a principal" do
          subj = stub("Subject")
          AccessControl.stub(:Principal).with(subj).
            and_return(principal)

          subject.should be_locally_assigned_at(node, subj)
        end

        it "returns false if the role was inherited" do
          local_assignment.propagate_to(child_node)
          subject.should_not be_locally_assigned_at(child_node, principal)
        end
      end
    end

    context "permissions management" do
      subject { Role.new(:name => "Irrelevant") }

      describe "#add_permissions" do
        let(:p1) { stub_permission }
        let(:p2) { stub_permission }
        let(:p3) { stub_permission }

        it "can be used to add many permissions at once" do
          subject.add_permissions([p1, p2, p3])
          subject.permissions.should include(p1, p2, p3)
        end

        it "doesn't include duplicates" do
          subject.add_permissions([p1, p1, p2])
          subject.permissions.count.should == 2
        end

        it "returns only the added permissions" do
          subject.add_permissions([p1, p2])

          return_value = subject.add_permissions([p1, p2, p3])
          return_value.should include_only(p3)
        end

        context "when the role is new" do
          it "persists added permissions when the role is saved" do
            subject.add_permissions([p1, p2])
            subject.persist!

            persisted_role = Role.fetch(subject.id)
            persisted_role.permissions.should include_only(p1, p2)
          end
        end

        context "when the role is already persisted" do
          it "persists the permissions at the moment they are added" do
            subject.add_permissions([p1])
            subject.persist!
            subject.add_permissions([p2])

            persisted_role = Role.fetch(subject.id)
            persisted_role.permissions.should include_only(p1, p2)
          end
        end
      end

      describe "#del_permissions" do
        let(:p1) { stub_permission }
        let(:p2) { stub_permission }
        let(:p3) { stub_permission }

        it "can be used to remove one permission at time" do
          subject.add_permissions([p1, p2])
          subject.del_permissions([p2])

          subject.permissions.should_not include(p2)
        end

        it "can be used to removed many permissions at once" do
          subject.add_permissions([p1, p2, p3])
          subject.del_permissions([p2, p1])

          subject.permissions.should_not include(p1, p2)
        end

        it "returns only the removed permissions" do
          subject.add_permissions([p1, p2, p3])
          subject.del_permissions([p1, p2])

          return_value = subject.del_permissions([p1, p2, p3])
          return_value.should include_only(p3)
        end

        context "when the role is new" do
          it "persists removal of permissions when the role is saved" do
            subject.add_permissions([p1, p2, p3])
            subject.del_permissions([p1, p2])
            subject.persist!

            persisted_role = Role.fetch(subject.id)
            persisted_role.permissions.to_a.should include_only(p3)
          end
        end

        context "when the role is already persisted" do
          it "removes the permissions at the moment they are added" do
            subject.add_permissions([p1, p2, p3])
            subject.persist!
            subject.del_permissions([p1, p2])

            persisted_role = Role.fetch(subject.id)
            persisted_role.permissions.to_a.should include_only(p3)
          end
        end
      end
    end

    context "when role is removed" do
      let(:role)      { Role.store(:name => 'Irrelevant') }
      let(:principal) { stub_principal }
      let(:node)      { stub_node }

      before do
        role.add_permissions([stub_permission])
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
        SecurityPolicyItem.filter(:role_id => role.id).should be_empty
      end
    end

    describe "subset delegation" do
      delegated_subsets = [:assigned_to, :globally_assigned_to, :assigned_at,
                           :for_all_permissions,
                           :default, :with_names]

      delegated_subsets.each do |delegated_subset|
        it "delegates the subset .#{delegated_subset} to the persistent model" do
          Role.delegated_subsets.should include(delegated_subset)
        end
      end
    end

    describe ".[]" do
      before do
        Role.store(:name => 'role1')
        Role.store(:name => 'role2')
      end

      it "returns the first role by the given name" do
        Role['role2'].name.should == 'role2'
      end

      it "returns nil if a role with the given name is not found" do
        Role['role3'].should be_nil
      end
    end
  end
end
