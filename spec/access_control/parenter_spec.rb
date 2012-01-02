require 'spec_helper'
require 'access_control/parenter'

module AccessControl
  describe Parenter do

    def make_node
      node = stub_model(Node)
      all_nodes[node.id] = node
    end

    let(:all_nodes) { {} }
    let(:node) { make_node }

    before do
      Node.stub(:fetch_all) { |ids| ids.map{|id| all_nodes[id]} }
    end

    after { AccessControl.db[:ac_parents].delete }

    it "takes a node as the only obligatory parameter" do
      lambda {
        Parenter.new(node)
      }.should_not raise_exception(ArgumentError)
    end

    it "can add a new parent and persist it" do
      parent = make_node()
      same_node = stub(:id => node.id)
      Parenter.new(node).add_parent(parent)

      Parenter.new(same_node).parents.should include(parent)
    end

    it "can add a new child and persist it" do
      child = make_node()
      same_node = stub(:id => node.id)
      Parenter.new(node).add_child(child)

      Parenter.new(same_node).children.should include(child)
    end

    it "can remove an existing parent and persist it" do
      parent = make_node()
      other_parent = make_node()
      same_node = stub(:id => node.id)

      parenter = Parenter.new(node)
      parenter.add_parent(parent)
      parenter.add_parent(other_parent)

      parenter = Parenter.new(node)
      parenter.del_parent(parent)

      parenter = Parenter.new(same_node)
      parenter.parents.should include(other_parent)
      parenter.parents.should_not include(parent)
    end

    it "can remove existing child and persist it" do
      child = make_node()
      other_child = make_node()
      same_node = stub(:id => node.id)

      parenter = Parenter.new(node)
      parenter.add_child(child)
      parenter.add_child(other_child)

      parenter = Parenter.new(node)
      parenter.del_child(child)

      parenter = Parenter.new(same_node)
      parenter.children.should include(other_child)
      parenter.children.should_not include(child)
    end

    it "can return only parent ids" do
      parent = make_node()
      Parenter.new(node).add_parent(parent)
      Parenter.new(node).parent_ids.should include(parent.id)
    end

    it "can return only child ids" do
      child = make_node()
      Parenter.new(node).add_child(child)
      Parenter.new(node).child_ids.should include(child.id)
    end

    describe ".parents_of" do
      it "works in the same way as Parenter.new(foo).parents" do
        parent = make_node()
        Parenter.new(node).add_parent(parent)
        Parenter.parents_of(node).should == Parenter.new(node).parents
      end
    end

    describe ".parent_ids_of" do
      it "works in the same way as Parenter.new(foo).parent_ids" do
        parent = make_node()
        Parenter.new(node).add_parent(parent)
        Parenter.parent_ids_of(node).should == Parenter.new(node).parent_ids
      end
    end

    describe ".children_of" do
      it "works in the same way as Parenter.new(foo).children" do
        child = make_node()
        Parenter.new(node).add_child(child)
        Parenter.children_of(node).should == Parenter.new(node).children
      end
    end

    describe ".parent_ids_of" do
      it "works in the same way as Parenter.new(foo).parent_ids" do
        child = make_node()
        Parenter.new(node).add_child(child)
        Parenter.child_ids(node).should == Parenter.new(node).child_ids
      end
    end
  end
end
