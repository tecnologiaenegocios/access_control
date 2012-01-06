require 'spec_helper'

module AccessControl
  describe DatasetHelper::ClassMethods do
    let(:model) { stub }

    before { model.extend(DatasetHelper::ClassMethods) }

    context "with subqueries enabled" do
      before { DatasetHelper.use_subqueries = true }
      after  { DatasetHelper.use_subqueries = nil  }

      describe ".column_dataset" do
        it "filters by column values and selects them" do
          # Both chains are accepted...
          values = stub
          result = stub
          filtered = stub
          selected = stub

          model.stub(:filter).with(:column => values).and_return(filtered)
          filtered.stub(:select).with(:column).and_return(result)

          model.stub(:select).with(:column).and_return(selected)
          selected.stub(:filter).with(:column => values).and_return(result)

          model.column_dataset(:column, values).should be result
        end
      end
    end

    context "with subqueries disabled" do
      describe ".column_dataset" do
        it "just return the given values" do
          values = stub
          model.column_dataset(:column, values).should be values
        end
      end
    end
  end
end
