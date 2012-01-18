require 'spec_helper'

module AccessControl
  describe Assignment do
    describe "subset delegation" do
      it "delegates subset .with_nodes to the persistent model" do
        Assignment.delegated_subsets.should include(:with_nodes)
      end

      it "delegates subset .with_roles to the persistent model" do
        Assignment.delegated_subsets.should include(:with_roles)
      end

      it "delegates subset .assigned_to to the persistent model" do
        Assignment.delegated_subsets.should include(:assigned_to)
      end

      it "delegates subset .assigned_on to the persistent model" do
        Assignment.delegated_subsets.should include(:assigned_on)
      end

      it "delegates subset .overlapping to the persistent model" do
        Assignment.delegated_subsets.should include(:overlapping)
      end

      it "delegates subset .effective to the persistent model" do
        Assignment.delegated_subsets.should include(:effective)
      end

      it "delegates subset .real to the persistent model" do
        Assignment.delegated_subsets.should include(:real)
      end

      it "delegates subset .children_of to the persistent model" do
        Assignment.delegated_subsets.should include(:children_of)
      end
    end

    context "when its persistent doesn't have a parent" do
      let(:persistent) { stub(:parent_id => nil) }

      subject { Assignment.wrap(persistent) }

      it { should     be_real }
      it { should_not be_effective }
    end

    context "when its persistent has a parent" do
      let(:persistent) { stub(:parent_id => stub) }

      subject { Assignment.wrap(persistent) }

      it { should     be_effective }
      it { should_not be_real }
    end

    describe "#propagate_to" do
      let(:node) { stub("Node", :id => 12345) }
      subject do
        Assignment.store(:node_id => 54321, :principal_id => 123,
                                            :role_id => 456)
      end

      let(:returned_assignment) { subject.propagate_to(node) }

      it "returns an assignment with the same principal and role" do
        returned_assignment.role_id.should == subject.role_id
        returned_assignment.principal_id.should == subject.principal_id
      end

      it "returns an assignment that points to the given node" do
        returned_assignment.node_id.should == node.id
      end

      it "returns an assignment that is a child of the original" do
        returned_assignment.parent_id.should == subject.id
      end

      it "returns a effective assignment" do
        returned_assignment.should be_effective
      end

      it "returns a saved assignment" do
        returned_assignment.should be_persisted
      end

      it "works if given an ID instead of a instance" do
        returned_assignment = subject.propagate_to(node.id)

        returned_assignment.node_id.should == node.id
        returned_assignment.should be_persisted
      end
    end

    describe "automatic propagation/depropagation" do
      let(:node_id)             { 12345 }
      let(:node)                { stub("Node", :id => node_id) }
      let(:inheritance_manager) { stub("Inheritance Manager") }

      let(:child1)     { stub("child 1", :id => 54321) }
      let(:child2)     { stub("child 2", :id => 12543) }

      let(:children_ids) { [child1.id, child2.id] }

      before do
        Node::InheritanceManager.stub(:new).with(node_id).
          and_return(inheritance_manager)

        inheritance_manager.stub(:descendant_ids).and_yield(node_id, children_ids)
      end

      subject do
        Assignment.new.tap do |assignment|
          assignment.node_id      = node_id
          assignment.role_id      = 55
          assignment.principal_id = 110
        end
      end

      context "after the assignment is created" do
        it "propagates the assignment to the node's descentants" do
          Assignment::Persistent.should_receive(:propagate_to_descendants).
            with([subject], subject.node_id)
          subject.persist
        end

        it "saves the persistent first, then propagates" do
          persistent = subject.persistent
          persistent.stub(:save) do
            Assignment::Persistent.already_persisted
          end

          Assignment::Persistent.should_receive(:already_persisted).ordered
          Assignment::Persistent.should_receive(:propagate_to_descendants).
            with(any_args).ordered

          subject.persist
        end
      end

      context "on the destruction of the assignment" do
        it "destroys the children assignments" do
          subject.persist
          Assignment::Persistent.should_receive(:destroy_children_of).
            with(subject.id)

          subject.destroy
        end
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
  end
end
