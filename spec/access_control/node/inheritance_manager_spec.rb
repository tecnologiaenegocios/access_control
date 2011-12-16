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

        describe "when the 'filter' parameter is passed" do
          let(:filter) do
            Proc.new do |parent|
              parent == parent1
            end
          end

          it "returns parents that the filter approved" do
            returned_set = subject.ancestors(filter)
            returned_set.should include parent1
          end

          it "doesn't return the parents that the filter didn't approve" do
            returned_set = subject.ancestors(filter)
            returned_set.should_not include parent2
          end

          it "forwards the filter to the approved parents #ancestors call" do
            parent1.should_receive(:ancestors).with(filter)
            subject.ancestors(filter)
          end

          it "never calls the unnaproved parents #ancestors" do
            parent2.should_not_receive(:ancestors)
            subject.ancestors(filter)
          end
        end
      end

    end

  end
end
