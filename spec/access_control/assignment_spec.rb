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
