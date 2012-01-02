require 'spec_helper'

module AccessControl
  class Role
    describe Persistent do
      let(:manager) { Manager.new }

      before do
        AccessControl.stub(:manager).and_return(manager)
      end

      it "is extended with AccessControl::Ids" do
        Persistent.singleton_class.should include(AccessControl::Ids)
      end

      describe ".assigned_to" do
        let(:principal) { stub("Principal", :id => 123) }
        let(:node)      { stub("Node",      :id => -1)  }
        let(:role)      { Persistent.create!(:name => "Foo")  }
        let(:assignment) { stub(:node => node, :principal => principal) }

        before do
          AccessControl.stub(:Node).with(node).and_return(node)
          role.assignments = [assignment]
        end

        it "includes roles that were assigned to the given principal" do
          Persistent.assigned_to(principal).should include role
        end

        it "doesn't include roles that not assigned to the given principal" do
          other_role = Persistent.create!(:name => "Bar")
          Persistent.assigned_to(principal).should_not include other_role
        end

        context "when a node is provided" do
          it "includes roles assigned to the principal on the node" do
            Persistent.assigned_to(principal, node).should include role
          end

          it "doesn't include roles assigned to the principal on other nodes" do
            other_node = stub("Other node", :id => -2)
            Persistent.assigned_to(principal, other_node).should_not include role
          end
        end
      end

      describe ".assigned_at" do
        let(:node)      { stub("Node",      :id => -1) }
        let(:principal) { stub("Principal", :id => -1) }
        let(:role)      { Persistent.create!(:name => "Foo") }
        let(:assignment) { stub(:node => node, :principal => principal) }

        before do
          AccessControl.stub(:Node).with(node).and_return(node)
          role.assignments = [assignment]
        end

        it "includes roles that were assigned on the given node" do
          Persistent.assigned_at(node).should include role
        end

        it "doesn't include roles that not assigned at the given node" do
          other_role = Persistent.create!(:name => "Bar")
          Persistent.assigned_at(node).should_not include other_role
        end

        context "when a principal is provided" do
          it "includes roles assigned on the node to the principal" do
            Persistent.assigned_at(node, principal).should include role
          end

          it "doesn't include roles assigned on the node to other principals" do
            other_principal = stub("Other principal", :id => -2)
            Persistent.assigned_at(node, other_principal).should_not include role
          end
        end
      end

      def build_role(properties = {})
        properties[:name] ||= "irrelevant"
        Persistent.create!(properties)
      end

      describe "the assignments" do
        def stub_assignment(node = nodes[0], principal = principals[0])
          OpenStruct.new(:node => node, :principal => principal)
        end

        let(:nodes) do
          Hash.new do |hash, id|
            node = stub("Node #{id}", :id => id)
            Node.stub(:fetch).with(id, anything).and_return(node)
            hash[id] = node
          end
        end

        let(:principals) do
          Hash.new do |hash, id|
            principal = stub("Principal #{id}", :id => id)
            Principal.stub(:fetch).with(id, anything).
              and_return(principal)
            hash[id] = principal
          end
        end

        specify "can be set as an Array" do
          assignments = [stub_assignment]
          setting_the_assignments = lambda do
            subject.assignments = assignments
          end

          setting_the_assignments.should_not raise_error
        end

        specify "can be set as a Set" do
          assignments = Set[stub_assignment]
          setting_the_assignments = lambda do
            subject.assignments = assignments
          end

          setting_the_assignments.should_not raise_error
        end

        specify "don't contain duplicated entries" do
          assignments = [stub_assignment]*2

          subject.assignments = assignments
          subject.assignments.count.should == 1
        end

        context "two assignments" do
          specify "are duplicated with the same #node and #principal" do
            a1 = stub_assignment(nodes[0], principals[0])
            a2 = stub_assignment(nodes[0], principals[0])
            subject.assignments = [a1, a2]

            accepted_assignments = subject.assignments
            accepted_assignments.count.should == 1
          end

          specify "aren't duplicated with different #node and #principal" do
            a1 = stub_assignment(nodes[0], principals[0])
            a2 = stub_assignment(nodes[1], principals[1])

            subject.assignments = [a1, a2]

            accepted_assignments = subject.assignments
            accepted_assignments.count.should == 2
          end

          specify "aren't duplicated with different #node but same #principal" do
            a1 = stub_assignment(nodes[0], principals[0])
            a2 = stub_assignment(nodes[1], principals[0])

            subject.assignments = [a1, a2]

            accepted_assignments = subject.assignments
            accepted_assignments.count.should == 2
          end

          specify "aren't duplicated with same #node but different #principal" do
            a1 = stub_assignment(nodes[0], principals[0])
            a2 = stub_assignment(nodes[0], principals[1])

            subject.assignments = [a1, a2]

            accepted_assignments = subject.assignments
            accepted_assignments.count.should == 2
          end
        end

        specify "are persisted" do
          assignments = [stub_assignment(nodes[0], principals[0])]
          subject = build_role(:assignments => assignments)

          persisted_subject = Role::Persistent.find(subject.id)
          persisted_assignments = persisted_subject.assignments

          persisted_assignments.map(&:node).should == [nodes[0]]
          persisted_assignments.map(&:principal).should == [principals[0]]
        end
      end

      describe "the permissions" do
        specify "can be set as a Set" do
          subject.permissions = Set["p1", "p2"]
          subject.permissions.should include("p1", "p2")
        end

        specify "can be set as any Enumerable" do
          subject.permissions = ('a'..'d')
          subject.permissions.should include *('a'..'d')
        end

        specify "don't contain duplicates" do
          subject.permissions = %w[p1 p1 p1 p2]
          subject.permissions.length.should == 2
        end

        specify "are persisted when the record is saved" do
          subject = build_role(:permissions => %w[p1 p2])

          persisted_subject = Persistent.find(subject.id)
          persisted_subject.permissions.should include("p1", "p2")
        end
      end

      describe ".for_all_permissions" do
        context "when given only one permission" do
          it "returns roles that have such permission" do
            role = build_role(:permissions => ["p1"])
            Role::Persistent.for_all_permissions("p1").should include(role)
          end

          it "doesn't return roles that doesn't have the permission" do
            role = build_role(:permissions => [])
            Role::Persistent.for_all_permissions("p1").should_not include(role)
          end
        end

        context "when given multiple permissions" do
          it "returns roles that have all the permissions" do
            role = build_role(:permissions => ["p1", "p2"])
            returned = Role::Persistent.for_all_permissions(["p1", "p2"])
            returned.should include(role)
          end

          it "doesn't return roles that don't have one of the permissions" do
            role = build_role(:permissions => ["p1"])
            returned = Role::Persistent.for_all_permissions(["p1", "p2"])
            returned.should_not include(role)
          end

          it "doesn't return roles that don't have any of the permissions" do
            role = build_role(:permissions => [])
            returned = Role::Persistent.for_all_permissions(["p1", "p2"])
            returned.should_not include(role)
          end
        end
      end

      describe ".local_assignables" do
        it "returns roles with local = true" do
          role = build_role(:local => true)
          Persistent.local_assignables.should include role
        end

        it "doesn't return roles with local = false" do
          role = build_role(:local => false)
          Persistent.local_assignables.should_not include role
        end
      end

      describe ".global_assignables" do
        it "returns roles with global = true" do
          role = build_role(:global => true)
          Persistent.global_assignables.should include role
        end

        it "doesn't return roles with global = false" do
          role = build_role(:global => false)
          Persistent.global_assignables.should_not include role
        end
      end

      describe ".default" do
        let(:roles_names) { ["owner"] }
        before do
          AccessControl.config.stub(:default_roles => roles_names)
        end

        it "contains roles whose name is in config.default_roles" do
          role = Persistent.create!(:name => "owner")
          Persistent.default.should include role
        end

        it "doesn't contain roles whose name isn't in config.default_roles" do
          role = Persistent.create!(:name => "user")
          Persistent.default.should_not include role
        end

        it "doesn't blow up when config returns a Set with multiple values" do
          AccessControl.config.stub(:default_roles => Set["owner", "manager"])
          role = Persistent.create!(:name => "owner")

          accessing_the_results = lambda { Persistent.default.include?(role) }
          accessing_the_results.should_not raise_error
        end
      end

      describe ".with_names" do
        let!(:role) { Persistent.create!(:name => "foo") }

        context "for string arguments" do
          it "returns roles whose name is the argument" do
            Persistent.with_names_in("foo").should include role
          end

          it "doesn't return roles whose name isn't argument" do
            Persistent.with_names_in("bar").should_not include role
          end
        end

        context "for set arguments" do
          it "returns roles whose name is included in the set" do
            names = Set["foo", "bar"]
            Persistent.with_names_in(names).should include role
          end

          it "doesn't return roles whose name isn't included in the set" do
            names = Set["baz", "bar"]
            Persistent.with_names_in(names).should_not include role
          end
        end
      end

    end
  end
end
