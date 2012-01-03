require 'spec_helper'

module AccessControl
  describe Assignment do
    describe "scope delegation" do
      it "delegates scope .with_nodes to the persistent model" do
        Assignment.delegated_scopes.should include(:with_nodes)
      end

      it "delegates scope .with_roles to the persistent model" do
        Assignment.delegated_scopes.should include(:with_roles)
      end

      it "delegates scope .assigned_to to the persistent model" do
        Assignment.delegated_scopes.should include(:assigned_to)
      end

      it "delegates scope .assigned_on to the persistent model" do
        Assignment.delegated_scopes.should include(:assigned_on)
      end

      it "delegates scope .overlapping to the persistent model" do
        Assignment.delegated_scopes.should include(:overlapping)
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
