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

    describe "propagation" do
      let(:node_id)             { 12345 }
      let(:node)                { stub("Node", :id => node_id) }
      let(:inheritance_manager) { stub("Inheritance Manager") }

      let(:descendant1)     { stub("Descendant 1", :id => 54321) }
      let(:descendant2)     { stub("Descendant 2", :id => 12543) }
      let(:descendants_ids) { [descendant1.id, descendant2.id] }

      before do
        Node::InheritanceManager.stub(:descendant_ids_of => [])
        Node::InheritanceManager.stub(:descendant_ids_of).with(node_id).
          and_return(descendants_ids)
      end

      subject do
        Assignment.new.tap do |assignment|
          assignment.node_id      = node_id
          assignment.role_id      = 55
          assignment.principal_id = 110
        end
      end

      context "after the assignment is created" do
        it "creates new assignments for each of the Node's decendants" do
          new_assignments_count = descendants_ids.count + 1

          lambda {
            subject.persist
          }.should change(Assignment, :count).by(new_assignments_count)
        end

        describe "the new assignments" do
          let(:new_assignments) do
            # Naive by design
            Assignment.all.to_a.reverse.take(descendants_ids.count)
          end

          before do
            subject.persist
          end

          specify "are effective" do
            new_assignments.each do |new_assignment|
              new_assignment.should be_effective
            end
          end

          specify "are not real" do
            new_assignments.each do |new_assignment|
              new_assignment.should_not be_real
            end
          end

          it "have parent_id pointing to the original assignment's id" do
            new_assignments.each do |new_assignment|
              new_assignment.parent_id.should == subject.id
            end
          end

          it "have the same role_id and principal_id of the parent" do
            new_assignments.each do |new_assignment|
              new_assignment.role_id.should == subject.role_id
            end
          end

          it "have the same principal_id of the parent" do
            new_assignments.each do |new_assignment|
              new_assignment.principal_id.should == subject.principal_id
            end
          end

          it "have node_id pointing to one of the node's descendants" do
            missing_descendants_ids = Set.new(descendants_ids)
            new_assignments.each do |new_assignment|
              missing_descendants_ids.delete(new_assignment.node_id)
            end

            missing_descendants_ids.should be_empty
          end
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
