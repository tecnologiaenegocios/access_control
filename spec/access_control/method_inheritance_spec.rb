require 'spec_helper'

module AccessControl
  describe MethodInheritance do
    let(:model) { Class.new }

    it "is initialized with a class and a method name" do
      subject = MethodInheritance.new(model, :foobar)
      subject.model_class.should == model
      subject.method_name.should == :foobar
    end


    let(:parent_node_id) { 12345 }
    let(:parent_node)    { stub("Parent node", :id => parent_node_id) }
    let(:parent)         { stub("Parent",   :node => parent_node) }
    let(:instance)       { stub("Instance", :parent => parent) }

    before do
      AccessControl.stub(:Node) { |obj| obj.node }
      model.stub(:all => [instance])
    end

    subject { MethodInheritance.new(model, :parent) }

    describe "parent_nodes_ids" do
      context "when given a collection" do
        it "acts on the values of the collection" do
          model.stub(:all => [])
          returned_nodes = subject.parent_nodes_ids([instance])
          returned_nodes.should include_only(parent_node_id)
        end
      end

      it "returns the ids of the nodes of the parent objects" do
        returned_nodes = subject.parent_nodes_ids
        returned_nodes.should include_only(parent_node_id)
      end
    end

    describe "parent_nodes_dataset" do
      let(:node_dataset) { stub }

      before do
        Node::Persistent.stub(:for_securables)
        Node::Persistent.stub(:for_securables).with([parent]).
          and_return(node_dataset)
      end

      context "when given a collection" do
        it "uses the parents of the collection as the argument to Node" do
          model.stub(:all => nil)

          returned_dataset = subject.parent_nodes_dataset([instance])
          returned_dataset.should be node_dataset
        end
      end

      it "returns the dataset returned by Node::Persistent" do
        returned_dataset = subject.parent_nodes_dataset
        returned_dataset.should be node_dataset
      end
    end
  end
end
