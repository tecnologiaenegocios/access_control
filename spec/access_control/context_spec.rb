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

        let(:node3) { stub_model(Node) }
        let(:record3) { stub(:ac_node => node3) }
        let(:record4) { stub(:ac_node => nil,
                             :parents_for_creation => [record1, record3]) }
        let(:record5) { stub(:ac_node => nil,
                             :parents_for_creation => [record1, record2]) }

        it "uses parents for creation (assumes that the object is a baby)" do
          Context.new([record4, record5]).nodes.
            should == Set.new([node1, node2, node3])
        end

      end

    end

  end

end
