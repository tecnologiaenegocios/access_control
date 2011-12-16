require 'spec_helper'
require 'access_control/context'

module AccessControl

  describe Context do

    let(:securable_class) { FakeSecurableClass.new }

    let(:node1) { stub_model(Node) }
    let(:node2) { stub_model(Node) }
    let(:record1) { securable_class.new(:ac_node => node1) }
    let(:record2) { securable_class.new(:ac_node => node2) }

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
        let(:record1) { securable_class.new(:ac_node => nil) }
        let(:record2) { securable_class.new(:ac_node => nil) }

        let(:parent1) { securable_class.new(:ac_node => node1) }
        let(:parent2) { securable_class.new(:ac_node => node2) }

        it "uses its parents (assumes that the object is a baby)" do
          Parenter.stub(:parents_of).with(record1).and_return(Set[parent1])
          Parenter.stub(:parents_of).with(record2).and_return(Set[parent2])

          Context.new([record1, record2]).nodes.should == Set[node1, node2]
        end

      end

    end

  end

end
