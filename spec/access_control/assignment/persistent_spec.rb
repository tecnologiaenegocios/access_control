require 'spec_helper'
require 'access_control/assignment/persistent'

module AccessControl
  class Assignment
    describe Persistent do
      it "is extended with AccessControl::Ids" do
        Persistent.singleton_class.should include(AccessControl::Ids)
      end

      def build_persistent(properties = {})
        properties[:principal_id] ||= 0
        properties[:node_id] ||= 0
        properties[:role_id] ||= 0

        Persistent.create!(properties)
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
        let(:a1) { build_persistent(:role_id => 1) }
        let(:a2) { build_persistent(:role_id => 2) }

        it "returns assignments for the given role" do
          Persistent.with_roles(1).should include(a1)
        end

        it "rejects assignments for different roles of the specified" do
          Persistent.with_roles(1).should_not include(a2)
        end

        it "accepts an array" do
          collection = Persistent.with_roles([1, 2])
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
        let(:assignment) do
          Persistent.new do |assignment|
            assignment.role_id      = 1
            assignment.principal_id = 2
            assignment.node_id      = 3
            assignment.save!
          end
        end

        it "returns assignments whose properties overlap the parameters" do
          Persistent.overlapping(1,2,3).should include assignment
        end

        it "doesn't return assignments whose properties don't overlap "\
           "the parameters" do
          Persistent.overlapping(3,2,1).should_not include assignment
        end

        it "works as a non-deterministic query as well" do
          roles      = [1,3]
          principals = [2,5]
          nodes      = [3,1]

          Persistent.overlapping(roles,principals,nodes).
            should include assignment
        end

        it "doesn't suffer from the 'Set' bug on queries" do
          roles      = Set[1,3]
          principals = Set[2,5]
          nodes      = Set[3,1]

          using_the_collection = lambda do
            Persistent.overlapping(roles,principals,nodes).any?
          end
          using_the_collection.should_not raise_error
        end
      end

      describe ".assigned_on" do

        let(:cls) { Persistent }

        let!(:a1) { cls.create!(:role_id=>1, :principal_id=>1, :node_id=>1) }
        let!(:a2) { cls.create!(:role_id=>2, :principal_id=>1, :node_id=>2) }
        let!(:a3) { cls.create!(:role_id=>3, :principal_id=>2, :node_id=>1) }
        let!(:a4) { cls.create!(:role_id=>4, :principal_id=>2, :node_id=>2) }
        let!(:a5) { cls.create!(:role_id=>5, :principal_id=>3, :node_id=>3) }

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
