require 'spec_helper'
require 'access_control/context'

module AccessControl

  describe Context do

    let(:node1) { stub_model(Node) }
    let(:node2) { stub_model(Node) }
    let(:record1) { stub(:ac_node => node1) }
    let(:record2) { stub(:ac_node => node2) }

    it "extracts a single node from, er, a node" do
      Context.new(node1).nodes.should == Set.new([node1])
    end

    it "extracts nodes from, er, nodes" do
      Context.new([node1, node2]).nodes.should == Set.new([node1, node2])
    end

    describe "with AR securable objects" do

      describe "if the object has a node" do

        it "extracts a single node from .ac_node" do
          Context.new(record1).nodes.should == Set.new([node1])
        end

        it "extracts nodes from a collection" do
          Context.new([record1, record2]).nodes.
            should == Set.new([node1, node2])
        end

      end

      describe "if the object hasn't a node" do

        let(:record1) { stub(:ac_node => nil) }
        let(:record2) { stub(:ac_node => nil) }
        let(:parent1) { Set.new([stub('parent 1', :ac_node => node1)]) }
        let(:parent2) { Set.new([stub('parent 2', :ac_node => node2)]) }
        let(:parenter1) { stub(:get => parent1) }
        let(:parenter2) { stub(:get => parent2) }

        it "uses its parents (assumes that the object is a baby)" do
          Parenter.should_receive(:new).with(record1).and_return(parenter1)
          Parenter.should_receive(:new).with(record2).and_return(parenter2)
          Context.new([record1, record2]).nodes.
            should == Set.new([node1, node2])
        end

      end

    end

  end

end
