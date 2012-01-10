require 'spec_helper'
require 'access_control/assignment/persistent'

module AccessControl
  class Assignment
    describe Persistent do
      def build_persistent(properties = {})
        @ids ||= Enumerator.new do |yielder|
          n = 0
          loop { yielder.yield(n+=1) }
        end

        properties[:principal_id] ||= @ids.next
        properties[:node_id]      ||= @ids.next
        properties[:role_id]      ||= @ids.next

        Persistent.create(properties)
      end

      describe ".real" do
        it "returns assignments that don't have a parent" do
          subject = build_persistent(:parent_id => nil)
          Persistent.real.should include subject
        end

        it "doesn't return assignments that have a parent" do
          subject = build_persistent(:parent_id => 1)
          Persistent.real.should_not include subject
        end
      end

      describe ".effective" do
        it "returns assignments that have a parent" do
          subject = build_persistent(:parent_id => 1)
          Persistent.effective.should include subject
        end

        it "doesn't return assignments that don't have a parent" do
          subject = build_persistent(:parent_id => nil)
          Persistent.effective.should_not include subject
        end
      end

      describe ".children_of" do
        let!(:assignment) { build_persistent }

        it "returns assignments whose 'parent_id' point to the param" do
          child = build_persistent(:parent_id => assignment.id)
          Persistent.children_of(assignment).should include(child)
        end

        it "doesn't return assignments with a different 'parent_id'" do
          random_assignment = build_persistent(:parent_id => assignment.id-1)
          Persistent.children_of(assignment).should_not include(random_assignment)
        end

        it "works the same if given an ID instead of an instance" do
          child             = build_persistent(:parent_id => assignment.id)
          random_assignment = build_persistent(:parent_id => assignment.id-1)

          returned_dataset = Persistent.children_of(assignment.id)
          returned_dataset.should include(child)
          returned_dataset.should_not include(random_assignment)
        end
      end

      describe ".with_nodes" do
        let(:node)         { stub(:id => 1) }
        let(:other_node)   { stub(:id => 2) }
        let(:another_node) { stub(:id => 3) }
        let(:assignment_of_node) { build_persistent(:node_id => node.id) }
        let(:assignment_of_other_node) do
          build_persistent(:node_id => other_node.id)
        end
        let(:assignment_of_another_node) do
          build_persistent(:node_id => another_node.id)
        end

        subject { Persistent.with_nodes(1) }

        it { should     discover(assignment_of_node) }
        it { should_not discover(assignment_of_other_node) }
        it { should_not discover(assignment_of_another_node) }

        describe "using actual nodes" do
          subject { Persistent.with_nodes(node) }

          it { should     discover(assignment_of_node) }
          it { should_not discover(assignment_of_other_node) }
          it { should_not discover(assignment_of_another_node) }
        end

        describe "using an array" do
          subject { Persistent.with_nodes([node, other_node]) }

          it { should     discover(assignment_of_node) }
          it { should     discover(assignment_of_other_node) }
          it { should_not discover(assignment_of_another_node) }
        end

        describe "using a set" do
          subject { Persistent.with_nodes(Set[node, other_node]) }

          it { should     discover(assignment_of_node) }
          it { should     discover(assignment_of_other_node) }
          it { should_not discover(assignment_of_another_node) }
        end
      end

      describe ".with_roles" do
        let!(:a1) { build_persistent(:role_id => 1) }
        let!(:a2) { build_persistent(:role_id => 2) }

        it "returns assignments for the given role" do
          Persistent.with_roles(1).should include(a1)
        end

        it "rejects assignments for different roles of the specified" do
          Persistent.with_roles(1).should_not include(a2)
        end

        it "accepts an array" do
          collection = Persistent.with_roles([1, 2]).to_a
          collection.should include(a1)
          collection.should include(a1)
        end
      end

      describe ".assigned_to" do
        let(:a1) { build_persistent(:principal_id => 1) }
        let(:a2) { build_persistent(:principal_id => 2) }

        it "returns assignments for the given principal" do
          Persistent.assigned_to(1).should include(a1)
        end

        it "rejects assignments for different principals of the specified" do
          Persistent.assigned_to(1).should_not include(a2)
        end

        it "accepts an array" do
          collection = Persistent.assigned_to([1, 2])
          collection.should include(a1)
          collection.should include(a1)
        end
      end

      describe ".overlapping" do
        let(:role)                  { stub(:id => 1) }
        let(:another_role)          { stub(:id => 2) }
        let(:yet_another_role)      { stub(:id => 3) }

        let(:node)                  { stub(:id => 1) }
        let(:another_node)          { stub(:id => 2) }
        let(:yet_another_node)      { stub(:id => 3) }

        let(:principal)             { stub(:id => 1) }
        let(:another_principal)     { stub(:id => 2) }
        let(:yet_another_principal) { stub(:id => 3) }

        def make_assignment(role, principal, node, parent_id = nil)
          Persistent.create(:role_id      => role.id,
                            :principal_id => principal.id,
                            :node_id      => node.id,
                            :parent_id    => parent_id)
        end

        it "returns exact matches if the assignment has no parent" do
          assignment = make_assignment(role, principal, node)
          matches    = Persistent.overlapping(role, principal, node)

          matches.should include(assignment)
        end

        it "doesn't return exact matches that have parents" do
          effective_assignment = make_assignment(role, principal, node, 1)
          matches    = Persistent.overlapping(role, principal, node)

          matches.should_not include(effective_assignment)
        end

        context "using single objects" do
          let!(:a1) { make_assignment(role,             principal, node) }
          let!(:a2) { make_assignment(another_role,     principal, node) }
          let!(:a3) { make_assignment(yet_another_role, principal, node) }
          let!(:a4) { make_assignment(role, another_principal,     node) }
          let!(:a5) { make_assignment(role, yet_another_principal, node) }
          let!(:a6) { make_assignment(role, principal,     another_node) }
          let!(:a7) { make_assignment(role, principal, yet_another_node) }

          it "matches by exact assignments" do
            matches = Persistent.overlapping(role, principal, node)
            matches.should include_only a1
          end

          it "matches by using ids directly" do
            matches = Persistent.overlapping(role.id, principal.id, node.id)
            matches.should include_only a1
          end
        end

        context "using role collections" do
          let!(:a1) { make_assignment(role,             principal, node) }
          let!(:a2) { make_assignment(another_role,     principal, node) }
          let!(:a3) { make_assignment(yet_another_role, principal, node) }

          it "matches by any object using an array" do
            matches = Persistent.
              overlapping([role, another_role], principal, node)
            matches.should include_only a1, a2
          end

          it "matches by any object using an array of ids" do
            matches = Persistent.
              overlapping([role.id, another_role.id], principal, node)
            matches.should include_only a1, a2
          end

          it "matches by any object using a set" do
            matches = Persistent.
              overlapping(Set[role, another_role], principal, node)
            matches.should include_only a1, a2
          end

          it "matches by any object using a set of ids" do
            matches = Persistent.
              overlapping(Set[role.id, another_role.id], principal, node)
            matches.should include_only a1, a2
          end
        end

        context "using principal collections" do
          let!(:a1) { make_assignment(role, principal,             node) }
          let!(:a2) { make_assignment(role, another_principal,     node) }
          let!(:a3) { make_assignment(role, yet_another_principal, node) }

          it "matches by any object using an array" do
            matches = Persistent.
              overlapping(role, [principal, another_principal], node)
            matches.should include_only a1, a2
          end

          it "matches by any object using an array of ids" do
            matches = Persistent.
              overlapping(role, [principal.id, another_principal.id], node)
            matches.should include_only a1, a2
          end

          it "matches by any object using a set" do
            matches = Persistent.
              overlapping(role, Set[principal, another_principal], node)
            matches.should include_only a1, a2
          end

          it "matches by any object using a set of ids" do
            matches = Persistent.
              overlapping(role, Set[principal.id, another_principal.id], node)
            matches.should include_only a1, a2
          end
        end

        context "using node collections" do
          let!(:a1) { make_assignment(role, principal, node) }
          let!(:a2) { make_assignment(role, principal, another_node) }
          let!(:a3) { make_assignment(role, principal, yet_another_node) }

          it "matches by any object using an array" do
            matches = Persistent.
              overlapping(role, principal, [node, another_node])
            matches.should include_only a1, a2
          end

          it "matches by any object using an array of ids" do
            matches = Persistent.
              overlapping(role, principal, [node.id, another_node.id])
            matches.should include_only a1, a2
          end

          it "matches by any object using a set" do
            matches = Persistent.
              overlapping(role, principal, Set[node, another_node])
            matches.should include_only a1, a2
          end

          it "matches by any object using a set of ids" do
            matches = Persistent.
              overlapping(role, principal, Set[node.id, another_node.id])
            matches.should include_only a1, a2
          end
        end
      end

      describe ".assigned_on" do

        let(:cls) { Persistent }

        let!(:a1) { cls.create(:role_id=>1, :principal_id=>1, :node_id=>1) }
        let!(:a2) { cls.create(:role_id=>2, :principal_id=>1, :node_id=>2) }
        let!(:a3) { cls.create(:role_id=>3, :principal_id=>2, :node_id=>1) }
        let!(:a4) { cls.create(:role_id=>4, :principal_id=>2, :node_id=>2) }
        let!(:a5) { cls.create(:role_id=>5, :principal_id=>3, :node_id=>3) }

        describe "using single ids" do
          subject { Persistent.assigned_on(1, 1) }
          it { should include_only(a1) }
        end

        describe "using single instances" do
          let(:principal) { stub(:id => 1) }
          let(:node)      { stub(:id => 1) }
          subject { Persistent.assigned_on(node, principal) }
          it { should include_only(a1) }
        end

        describe "using arrays of ids" do
          subject { Persistent.assigned_on([2,3], [1,3]) }
          it { should include_only(a2, a5) }
        end

        describe "using arrays of instances" do
          let(:principal1) { stub(:id => 1) }
          let(:principal2) { stub(:id => 3) }
          let(:node1)      { stub(:id => 2) }
          let(:node2)      { stub(:id => 3) }
          subject { Persistent.assigned_on([node1, node2],
                                           [principal1, principal2]) }
          it { should include_only(a2, a5) }
        end
      end
    end
  end
end
