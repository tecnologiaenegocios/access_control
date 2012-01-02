require 'spec_helper'

module AccessControl

  describe Assignment do

    let(:manager) { Manager.new }

    before do
      AccessControl.config.stub(:default_roles).and_return(Set.new)
      AccessControl.stub(:manager).and_return(manager)
    end

    it "is extended with AccessControl::Ids" do
      singleton_class = (class << Assignment; self; end)
      singleton_class.should include(AccessControl::Ids)
    end

    describe ".overlapping" do
      let(:assignment) do
        Assignment.new do |assignment|
          assignment.role_id      = 1
          assignment.principal_id = 2
          assignment.node_id      = 3
          assignment.save!
        end
      end

      it "returns assignments whose properties overlap the parameters" do
        Assignment.overlapping(1,2,3).should include assignment
      end

      it "doesn't return assignments whose properties don't overlap the parameters" do
        Assignment.overlapping(3,2,1).should_not include assignment
      end

      it "works as a non-deterministic query as well" do
        roles      = [1,3]
        principals = [2,5]
        nodes      = [3,1]

        Assignment.overlapping(roles,principals,nodes).
          should include assignment
      end

      it "doesn't suffer from the 'Set' bug on queries" do
        roles      = Set[1,3]
        principals = Set[2,5]
        nodes      = Set[3,1]

        using_the_collection = lambda do
          Assignment.overlapping(roles,principals,nodes).any?
        end
        using_the_collection.should_not raise_error
      end
    end

    describe "#overlaps?" do
      let(:properties) { {:node_id => 1, :role_id => 3, :principal_id => 2} }

      subject { Assignment.new(properties) }

      it "is true if the other assignment has the same properties" do
        assignment = Assignment.new(properties)
        subject.overlaps?(assignment).should be_true
      end

      it "is false if the other assignment has not the same properties" do
        different_properties = properties.merge(:node_id => -1)

        assignment = Assignment.new(different_properties)
        subject.overlaps?(assignment).should be_false
      end
    end

    def build_assignment(properties = {})
      properties[:principal_id] ||= 0
      properties[:node_id] ||= 0
      properties[:role_id] ||= 0

      Assignment.create!(properties)
    end

    describe ".with_nodes" do
      let(:node)         { stub(:id => 1) }
      let(:other_node)   { stub(:id => 2) }
      let(:another_node) { stub(:id => 3) }
      let(:assignment_of_node) { build_assignment(:node_id => node.id) }
      let(:assignment_of_other_node) do
        build_assignment(:node_id => other_node.id)
      end
      let(:assignment_of_another_node) do
        build_assignment(:node_id => another_node.id)
      end

      subject { Assignment.with_nodes(1) }

      it { should     discover(assignment_of_node) }
      it { should_not discover(assignment_of_other_node) }
      it { should_not discover(assignment_of_another_node) }

      describe "using actual nodes" do
        subject { Assignment.with_nodes(node) }

        it { should     discover(assignment_of_node) }
        it { should_not discover(assignment_of_other_node) }
        it { should_not discover(assignment_of_another_node) }
      end

      describe "using an array" do
        subject { Assignment.with_nodes([node, other_node]) }

        it { should     discover(assignment_of_node) }
        it { should     discover(assignment_of_other_node) }
        it { should_not discover(assignment_of_another_node) }
      end

      describe "using a set" do
        subject { Assignment.with_nodes(Set[node, other_node]) }

        it { should     discover(assignment_of_node) }
        it { should     discover(assignment_of_other_node) }
        it { should_not discover(assignment_of_another_node) }
      end
    end

    describe ".with_roles" do
      let(:a1) { build_assignment(:role_id => 1) }
      let(:a2) { build_assignment(:role_id => 2) }

      it "returns assignments for the given role" do
        Assignment.with_roles(1).should include(a1)
      end

      it "rejects assignments for different roles of the specified" do
        Assignment.with_roles(1).should_not include(a2)
      end

      it "accepts an array" do
        collection = Assignment.with_roles([1, 2])
        collection.should include(a1)
        collection.should include(a1)
      end
    end

    describe ".assigned_to" do
      let(:a1) { build_assignment(:principal_id => 1) }
      let(:a2) { build_assignment(:principal_id => 2) }

      it "returns assignments for the given principal" do
        Assignment.assigned_to(1).should include(a1)
      end

      it "rejects assignments for different principals of the specified" do
        Assignment.assigned_to(1).should_not include(a2)
      end

      it "accepts an array" do
        collection = Assignment.assigned_to([1, 2])
        collection.should include(a1)
        collection.should include(a1)
      end
    end

    describe ".granting" do

      let(:roles_proxy) { stub('roles proxy', :ids => [1]) }

      let(:a1) { build_assignment(:role_id => 1) }
      let(:a2) { build_assignment(:role_id => 2) }

      before do
        Role.stub(:for_permission).and_return(roles_proxy)
      end

      it "returns assignments with the relevant role_id" do
        Assignment.granting('some permission').should include(a1)
      end

      it "rejects assignments without the relevant role_id" do
        Assignment.granting('some permission').should_not include(a2)
      end
    end

    describe ".granting_for_principal" do
      let(:granting_proxy) { stub('granting proxy') }
      let(:assignment_proxy) { stub('assignment proxy') }

      before do
        Assignment.stub(:granting).and_return(granting_proxy)
        granting_proxy.stub(:assigned_to).and_return(assignment_proxy)
      end

      it "calls .granting with permission provided" do
        Assignment.should_receive(:granting).with('permission').
          and_return(granting_proxy)
        Assignment.granting_for_principal('permission', 'principal')
      end

      it "calls .assigned_to with principal provided in the resulting object" do
        granting_proxy.should_receive(:assigned_to).with('principal')
        Assignment.granting_for_principal('permission', 'principal')
      end

      it "returns whatever .assigned_to returns" do
        Assignment.granting_for_principal('permission', 'principal').should ==
          assignment_proxy
      end
    end

  end

end
