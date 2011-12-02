require 'spec_helper'
require 'access_control/blockable'

module AccessControl
  describe Blockable do

    let(:model) { Class.new }

    it "can be created with a model" do
      Blockable.new(model)
    end

    describe "#ids" do

      let(:blockable) { Blockable.new(model) }
      let(:scoped)    { stub('scoped', :select_values_of_column => [0, 14528])}

      before do
        model.stub(:name).and_return('Record')
        Node.stub(:blocked_for).and_return(scoped)
      end

      it "finds all nodes for that type of record" do
        Node.should_receive(:blocked_for).
          with('Record').and_return(scoped)
        blockable.ids
      end

      it "gets only the securable_id column" do
        scoped.should_receive(:select_values_of_column).with(:securable_id).
          and_return([])
        blockable.ids
      end

      it "returns the securable ids of the nodes" do
        blockable.ids.should include(14528)
      end

      it "excludes the zero node (the class node)" do
        blockable.ids.size.should == 1
      end

      it "returns a Set" do
        # This makes sense since order doesn't matter.  Also, we can't mix
        # arrays with sets in many operations, so when sensible (the order
        # doesn't matter) return a set.
        blockable.ids.should be_a(Set)
      end

    end

  end
end
