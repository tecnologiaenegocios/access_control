require 'spec_helper'

module AccessControl
  class Role
    describe Persistent do

      def persist_role(properties = {})
        properties[:name] ||= "irrelevant"
        Persistent.new(properties).save(:raise_on_failure => true)
      end

      describe ".assigned_to" do
        let(:principal) { stub("Principal", :id => 123) }
        let(:node)      { stub("Node",      :id => -1)  }
        let(:role)      { persist_role(:name => "Foo") }

        before do
          AccessControl.stub(:Node).with(node).and_return(node)
          Assignment.store(:role_id => role.id,
                           :node_id => node.id,
                           :principal_id => principal.id)
        end

        it "includes roles that were assigned to the given principal" do
          Persistent.assigned_to(principal).should include role
        end

        it "doesn't include roles that not assigned to the given principal" do
          other_role = persist_role(:name => "Bar")
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
        let(:role)      { persist_role(:name => "Foo") }

        before do
          AccessControl.stub(:Node).with(node).and_return(node)
          Assignment.store(:role_id => role.id,
                           :node_id => node.id,
                           :principal_id => principal.id)
        end

        it "includes roles that were assigned on the given node" do
          Persistent.assigned_at(node).should include role
        end

        it "doesn't include roles that not assigned at the given node" do
          other_role = persist_role(:name => "Bar")
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
          subject = persist_role(:permissions => %w[p1 p2])

          persisted_subject = Persistent.with_pk(subject.id)
          persisted_subject.permissions.should include("p1", "p2")
        end
      end

      describe ".for_all_permissions" do
        context "when given only one permission" do
          it "returns roles that have such permission" do
            role = persist_role(:permissions => ["p1"])
            Role::Persistent.for_all_permissions("p1").should include(role)
          end

          it "doesn't return roles that doesn't have the permission" do
            role = persist_role(:permissions => [])
            Role::Persistent.for_all_permissions("p1").should_not include(role)
          end
        end

        context "when given multiple permissions" do
          it "returns roles that have all the permissions" do
            role = persist_role(:permissions => ["p1", "p2"])
            returned = Role::Persistent.for_all_permissions(["p1", "p2"])
            returned.should include(role)
          end

          it "doesn't return roles that don't have one of the permissions" do
            role = persist_role(:permissions => ["p1"])
            returned = Role::Persistent.for_all_permissions(["p1", "p2"])
            returned.should_not include(role)
          end

          it "doesn't return roles that don't have any of the permissions" do
            role = persist_role(:permissions => [])
            returned = Role::Persistent.for_all_permissions(["p1", "p2"])
            returned.should_not include(role)
          end
        end
      end

      describe ".local_assignables" do
        it "returns roles with local = true" do
          role = persist_role(:local => true)
          Persistent.local_assignables.should include role
        end

        it "doesn't return roles with local = false" do
          role = persist_role(:local => false)
          Persistent.local_assignables.should_not include role
        end
      end

      describe ".global_assignables" do
        it "returns roles with global = true" do
          role = persist_role(:global => true)
          Persistent.global_assignables.should include role
        end

        it "doesn't return roles with global = false" do
          role = persist_role(:global => false)
          Persistent.global_assignables.should_not include role
        end
      end

      describe ".default" do
        let(:roles_names) { ["owner"] }
        before do
          AccessControl.config.stub(:default_roles => roles_names)
        end

        it "contains roles whose name is in config.default_roles" do
          role = persist_role(:name => "owner")
          Persistent.default.should include role
        end

        it "doesn't contain roles whose name isn't in config.default_roles" do
          role = persist_role(:name => "user")
          Persistent.default.should_not include role
        end

        it "doesn't blow up when config returns a Set with multiple values" do
          AccessControl.config.stub(:default_roles => Set["owner", "manager"])
          role = persist_role(:name => "owner")

          accessing_the_results = lambda { Persistent.default.include?(role) }
          accessing_the_results.should_not raise_error
        end
      end

      describe ".with_names" do
        let!(:role) { persist_role(:name => "foo") }

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
