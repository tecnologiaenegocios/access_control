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

    describe "automatic propagation" do
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
        it "creates new assignments for each of the Node's decendants" do
          new_assignments_count = children_ids.count + 1

          lambda {
            subject.persist
          }.should change(Assignment, :count).by(new_assignments_count)
        end

        describe "the new assignments" do
          let(:new_assignments) do
            Assignment.all.to_a.reverse.take(children_ids.count)
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

          it "have the same role_id of the parent" do
            new_assignments.each do |new_assignment|
              new_assignment.role_id.should == subject.role_id
            end
          end

          it "have the same principal_id of the parent" do
            new_assignments.each do |new_assignment|
              new_assignment.principal_id.should == subject.principal_id
            end
          end

          it "have node_id pointing to one of the node's children" do
            missing_children_ids = Set.new(children_ids)
            new_assignments.each do |new_assignment|
              missing_children_ids.delete(new_assignment.node_id)
            end

            missing_children_ids.should be_empty
          end
        end

        context "when the node has second-order children" do
          let(:second_order_child) { stub("2nd order child", :id => 666) }
          let(:second_order_children_ids) { [second_order_child.id] }

          before do
            inheritance_manager.stub(:descendant_ids).
              and_yield(node_id,   children_ids).
              and_yield(child2.id, second_order_children_ids)
          end

          it "creates new assignments for each of them" do
            new_assignments_count = second_order_children_ids.count +
                                    children_ids.count + 1

            lambda {
              subject.persist
            }.should change(Assignment, :count).by(new_assignments_count)
          end

          context "the created 'second-order' assignments" do
            before do
              subject.persist
            end

            let(:first_order_assignment) do
              Assignment.with_nodes(child2.id).to_a.first
            end

            let(:second_order_assignments) do
              Assignment.all.to_a.reverse.take(second_order_children_ids.count)
            end

            it "have the parent_id as the assignment that is their parent" do
              second_order_assignments.each do |assignment|
                assignment.parent_id.should == first_order_assignment.id
              end
            end

            it "have the same role_id of the parent" do
              second_order_assignments.each do |assignment|
                assignment.role_id.should == first_order_assignment.role_id
              end
            end

            it "have the same principal_id of the parent" do
              second_order_assignments.each do |assignment|
                assignment.principal_id.should ==
                  first_order_assignment.principal_id
              end
            end

            specify "are effective" do
              second_order_assignments.each do |assignment|
                assignment.should be_effective
              end
            end

            specify "are not real" do
              second_order_assignments.each do |assignment|
                assignment.should_not be_real
              end
            end

            it "have node_id pointing to one of the node's 2nd order children" do
              missing_children_ids = Set.new(second_order_children_ids)
              second_order_assignments.each do |assignment|
                missing_children_ids.delete(assignment.node_id)
              end

              missing_children_ids.should be_empty
            end
          end
        end
      end

      context "on the destruction of the assignment" do
        let(:assignment_children) { Assignment.children_of(subject) }

        it "destroys one assignment for each of the node's children" do
          subject.persist

          destroyed_assignments_count = children_ids.count + 1
          lambda {
            subject.destroy
          }.should change(Assignment, :count).by(-destroyed_assignments_count)
        end

        it "destroys the 'children' of the assignment" do
          subject.persist
          subject.destroy

          assignment_children.each do |child|
            Assignment.has?(child.id).should be_false
          end
        end

        context "when the assignment has second-order children" do
          before do
            second_order_child = stub("2nd order child", :id => 666)

            Node::InheritanceManager.stub(:child_ids_of).with(child2.id).
              and_return([second_order_child.id])
            subject.persist
          end

          let!(:second_order_children) do
            Util.flat_set(assignment_children) do |child|
              Assignment.children_of(child)
            end
          end

          specify "they are destroyed too" do
            subject.destroy

            second_order_children.each do |child|
              Assignment.has?(child.id).should be_false
            end
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
