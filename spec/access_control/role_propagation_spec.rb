require 'spec_helper'

module AccessControl
  describe RolePropagation do

    let(:node)         { stub("Node", :id => 12345) }
    let(:node_parents) { [stub("Node parents")] }

    describe "on initialization" do
      it "takes as optional argument the collection of the node's parents" do
        lambda {
          RolePropagation.new(node, node_parents)
        }.should_not raise_exception(ArgumentError)
      end

      context "when given the second argument" do
        it "uses its contents as the node's parents" do
          propagation = RolePropagation.new(node, node_parents)
          propagation.node_parents.should == node_parents
        end
      end

      context "when not given the second argument" do
        it "uses the response from Node::InheritanceManager to fetch the parents" do
          response = stub("Response from InheritanceManager")
          Node::InheritanceManager.stub(:parents_of).with(node).and_return(response)

          propagation = RolePropagation.new(node)
          propagation.node_parents.should == response
        end
      end
    end

    subject { RolePropagation.new(node, node_parents) }

    describe "the collection of assignments relevant to the propagation" do
      context "when the node has parents" do
        let(:assignments) { [stub, stub] }

        before do
          Assignment::Persistent.stub(:with_nodes).with(node_parents).
                                 and_return(assignments)
        end

        specify "are the assignments returned by the Assignment class" do
          subject.relevant_assignments.should include_only(*assignments)
        end
      end

      context "when the node has no parents" do
        let(:node_parents) { Array.new }

        specify "doesn't touch the Assignment class" do
          Assignment::Persistent.should_not_receive(:with_nodes)
          subject.relevant_assignments
        end

        specify "is empty" do
          subject.relevant_assignments.should be_empty
        end
      end

      it "can be set externally" do
        relevant_assignments         = stub("Relevant assignments")
        subject.relevant_assignments = relevant_assignments

        subject.relevant_assignments.should == relevant_assignments
      end
    end

    describe "#propagate!" do
      let(:assignments) { stub("Assignments dataset") }

      it "uses Assignment.propagate_to to create the new assignments" do
        subject.relevant_assignments = assignments

        Assignment::Persistent.should_receive(:propagate_to).
          with(assignments, node.id)

        subject.propagate!
      end

    end

    describe "#depropagate!" do
      let(:assignments) { stub("Assignments dataset") }

      it "uses Assignment.depropagate_from to wipe out assignments" do
        subject.relevant_assignments = assignments

        Assignment::Persistent.should_receive(:depropagate_from).
          with(assignments, node.id)

        subject.depropagate!
      end
    end
  end
end
