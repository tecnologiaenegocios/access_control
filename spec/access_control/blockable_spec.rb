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
      let(:node1)     { stub('node1', :securable_id => 0) }
      let(:node2)     { stub('node1', :securable_id => 14528) }

      before do
        model.stub(:name).and_return('Record')
        Node.stub(:blocked_for).and_return([node1, node2])
      end

      it "finds all nodes for that type of record" do
        Node.should_receive(:blocked_for).
          with('Record').and_return([node1, node2])
        blockable.ids
      end

      it "returns the securable ids of the nodes" do
        blockable.ids.should include(14528)
      end

      it "excludes the zero node (the class node)" do
        blockable.ids.size.should == 1
      end

    end

  end
end
