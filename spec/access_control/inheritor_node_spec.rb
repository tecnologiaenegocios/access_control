require 'spec_helper'

module AccessControl
  describe InheritorNode do

    # Helper methods (to improve readability) {{{
    def stub_node(name, securable = nil)
      stub(name).tap do |node|
        securable ||= stub("#{name} Securable")
        node.stub(:securable => securable)
      end
    end

    def turn_on_inheritance_for(*nodes)
      nodes.each do |node|
        Inheritance.stub(:recognizes?).with(node.securable).and_return(true)
      end
    end

    def turn_off_inheritance_for(*nodes)
      nodes.each do |node|
        Inheritance.stub(:recognizes?).with(node.securable).and_return(false)
      end
    end

    def set_parent_nodes_of(node, options)
      parents = options.fetch(:as)

      turn_on_inheritance_for(node)
      Parenter.stub(:parent_nodes_of).with(node.securable).
        and_return parents
    end

    def set_parents_of_the_securable_of(node, options)
      parents = options.fetch(:as)

      turn_on_inheritance_for(node)
      Parenter.stub(:parents_of).with(node.securable).
        and_return parents
    end
    # }}}

    let(:securable) { stub("Node's securable") }
    let(:node) { stub("Underlying node", :securable => securable) }

    subject { InheritorNode.new(node) }

    it "delegates unknown methods to its underlying node" do
      node.stub(:name => "A very nice node")
      subject.name.should == "A very nice node"
    end

    it "doesn't suffer from the Object#id 'bug'" do
      node.stub(:id => 12345)
      subject.id.should == 12345
    end

    describe "the AccessControl.InheritorNode method" do
      let(:orphan_node) { stub(:name => "Orphan node") }

      it "wraps an object that is not an InheritorNode in a InheritorNode" do
        result = AccessControl::InheritorNode(orphan_node)
        result.name.should == "Orphan node"
      end

      it "simply returns an object that already is an InheritorNode" do
        inheritor_node = InheritorNode.new(orphan_node)
        result = AccessControl::InheritorNode(inheritor_node)

        result.should be inheritor_node
      end
    end

    describe "#parents" do

      context "when the securable is recognized by Inheritance" do
        let(:parent_nodes) { stub("A parent nodes collection") }

        it "uses parenter to fetch the 'parents_nodes_of' the securable" do
          set_parent_nodes_of(node, :as => parent_nodes)
          subject.parents.should == parent_nodes
        end
      end


      context "when the securable isn't recognized by Inheritance" do
        before { turn_off_inheritance_for(node) }

        it "returns an empty set" do
          subject.parents.should == Set[]
        end
      end
    end

    describe "#securable_parents" do

      context "when the securable is recognized by Inheritance" do
        let(:parents_set) { stub("Parents set") }

        it "uses parenter to fetch the 'parents_of' the securable" do
          set_parents_of_the_securable_of(node, :as => parents_set)
          subject.securable_parents.should == parents_set
        end
      end

      context "when the securable isn't recognized by Inheritance" do
        before { turn_off_inheritance_for(node) }

        it "returns an empty set" do
          subject.securable_parents.should == Set[]
        end
      end
    end

    describe "#ancestors" do
      before { Inheritance.stub(:recognizes?) }

      context "when the securable isn't recognized by Inheritance" do
        before { turn_off_inheritance_for(node) }

        it "returns an empty set" do
          subject.ancestors.should == Set[]
        end
      end

      context "when the securable is recognized by Inheritance" do
        let(:parent1) { stub_node("Parent1") }
        let(:parent2) { stub_node("Parent2") }

        before do
          set_parent_nodes_of(node, :as => [parent1, parent2])
        end

        it "contains the node's parents" do
          subject.ancestors.should include(parent1, parent2)
        end

        context "and the securable's parents are recognized as well" do
          let(:ancestor1) { stub_node("Ancestor 1") }
          let(:ancestor2) { stub_node("Ancestor 2") }

          before do
            set_parent_nodes_of(parent1, :as => Set[ancestor1])
            set_parent_nodes_of(parent2, :as => Set[ancestor2])
          end

          it "contains the parents of the node's parents" do
            subject.ancestors.should include(ancestor1, ancestor2)
          end
        end

        context "and the securable's parents aren't recognized" do
          let(:ancestor1) { stub_node("Ancestor 1") }
          let(:ancestor2) { stub_node("Ancestor 2") }

          before do
            set_parent_nodes_of(parent1, :as => Set[ancestor1])
            set_parent_nodes_of(parent2, :as => Set[ancestor2])
            turn_off_inheritance_for(parent1, parent2)
          end

          it "doesn't contain the parents of the node's parents" do
            subject.ancestors.should_not include(ancestor1, ancestor2)
          end
        end
      end

    end

  end
end
