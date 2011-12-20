# vim: fdm=marker
require 'spec_helper'

module AccessControl
  describe Node::InheritanceManager do

    # Helper methods (to improve readability) {{{
    def stub_node(name, *args)
      stub(name, *args).tap do |node|
        securable = stub("#{name} Securable")
        node.stub(:securable => securable)
        node.stub(:ancestors => Set[node])
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
      node.stub(:parents => parents)
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

    before { Inheritance.stub(:recognizes? => false) }

    let(:securable) { stub("Node's securable") }
    let(:node) { stub("Underlying node", :securable => securable) }

    subject { Node::InheritanceManager.new(node) }

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
        let(:ancestor1) { stub_node("Ancestor 1") }
        let(:ancestor2) { stub_node("Ancestor 2") }

        before do
          set_parent_nodes_of(node, :as => [parent1, parent2])

          parent1.stub(:ancestors => Set[ancestor1, parent1])
          parent2.stub(:ancestors => Set[ancestor2, parent2])
        end

        it "contains the node's parents" do
          subject.ancestors.should include(parent1, parent2)
        end

        it "contain each of the parent nodes ancestors" do
          subject.ancestors.should include(ancestor1, ancestor2)
        end

        let(:global_node) { stub("Global Node") }

        before do
          AccessControl.stub(:global_node => global_node)
        end

        it "includes the GlobalNode" do
          subject.ancestors.should include(global_node)
        end

      end

    end

    describe "#filtered_ancestors" do
      let(:parent1)   { stub_node("Parent 1", :recursable? => true) }
      let(:parent2)   { stub_node("Parent 2", :recursable? => false) }
      let(:ancestor1) { stub_node("Ancestor 1") }
      let(:ancestor2) { stub_node("Ancestor 2") }

      before do
        set_parent_nodes_of(node, :as => Set[parent1, parent2])

        set_parent_nodes_of(parent1, :as => Set[ancestor1])
        set_parent_nodes_of(parent2, :as => Set[ancestor2])
      end

      let(:returned_set) { subject.filtered_ancestors(:recursable?) }

      it "returns recursable parents" do
        returned_set.should include parent1
      end

      it "returns non-recursable parents" do
        returned_set.should include parent2
      end

      it "returns the ancestors of recursable parents" do
        returned_set.should include ancestor1
      end

      it "doesn't return the ancestors non-recursable parents" do
        returned_set.should_not include ancestor2
      end

      it "works with bigger hierarchies" do
        far_away_ancestor = stub_node("Far away ancestor")
        set_parent_nodes_of(ancestor1, :as => Set[far_away_ancestor])
        ancestor1.stub(:recursable? => true)

        returned_set.should include far_away_ancestor
      end
    end

  end
end
