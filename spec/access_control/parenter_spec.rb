require 'spec_helper'
require 'access_control/parenter'

module AccessControl
  describe Parenter do

    let(:model) { Class.new }

    it "takes a record as the single initialization parameter" do
      model.stub(:inherits_permissions_from)
      Parenter.new(model.new)
    end

    it "complains if model doesn't respond to #inherits_permissions_from" do
      lambda { Parenter.new(model.new) }.
        should raise_exception(InvalidInheritage)
    end

    describe "when the record has inheritance" do

      let(:record) { model.new }
      let(:global_record) { AccessControl::GlobalRecord.instance }

      before do
        model.stub(:inherits_permissions_from).and_return([:parent1, :parent2])
      end

      it "gets the record parents" do
        parent1 = stub('parent 1')
        parent2 = stub('parent 2')
        record.should_receive(:parent1).and_return(parent1)
        record.should_receive(:parent2).and_return(parent2)
        Parenter.new(record).get.should == Set.new([parent1, parent2])
      end

      it "doesn't break if the some of the parents are nil" do
        parent1 = stub('parent 1')
        record.stub(:parent1).and_return(parent1)
        record.stub(:parent2).and_return(nil)
        Parenter.new(record).get.should == Set.new([parent1])
      end

      it "merges collection associations" do
        parent1 = stub('parent 1')
        parent2 = stub('parent 2')
        parent3 = [parent1, parent2]
        parent4 = stub('parent 4')
        record.stub(:parent1).and_return(parent3)
        record.stub(:parent2).and_return(parent4)
        Parenter.new(record).get.should == Set.new([parent1, parent2, parent4])
      end

      it "returns the global record if the record hasn't parents" do
        record.stub(:parent1).and_return(nil)
        record.stub(:parent2).and_return(nil)
        Parenter.new(record).get.should == Set.new([global_record])
      end

    end

  end
end
