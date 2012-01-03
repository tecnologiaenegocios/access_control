# vim: fdm=marker
require 'spec_helper'
require 'access_control/node/inheritance_manager'

module AccessControl
  class Node
    describe InheritanceManager do

      def make_node
        node = stub_model(Node)
        all_nodes[node.id] = node
      end

      let(:all_nodes) { {} }
      let(:node) { make_node }
      let(:global_node) { stub("Global Node") }

      before do
        Node.stub(:fetch_all) { |ids| ids.map{|id| all_nodes[id]} }
        AccessControl.stub(:global_node => global_node)
      end

      describe "immediate parents and children API" do
        it "can add a new parent and persist it" do
          parent = make_node()
          same_node = stub(:id => node.id)
          InheritanceManager.new(node).add_parent(parent)

          InheritanceManager.new(same_node).parent_ids.
            should include(parent.id)
        end

        it "can add a new child and persist it" do
          child = make_node()
          same_node = stub(:id => node.id)
          InheritanceManager.new(node).add_child(child)

          InheritanceManager.new(same_node).child_ids.should include(child.id)
        end

        it "can remove an existing parent and persist it" do
          parent = make_node()
          other_parent = make_node()
          same_node = stub(:id => node.id)

          parenter = InheritanceManager.new(node)
          parenter.add_parent(parent)
          parenter.add_parent(other_parent)

          parenter = InheritanceManager.new(node)
          parenter.del_parent(parent)

          ids = InheritanceManager.new(same_node).parent_ids
          ids.should include(other_parent.id)
          ids.should_not include(parent.id)
        end

        it "can remove existing child and persist it" do
          child = make_node()
          other_child = make_node()
          same_node = stub(:id => node.id)

          parenter = InheritanceManager.new(node)
          parenter.add_child(child)
          parenter.add_child(other_child)

          parenter = InheritanceManager.new(node)
          parenter.del_child(child)

          ids = InheritanceManager.new(same_node).child_ids
          ids.should include(other_child.id)
          ids.should_not include(child.id)
        end

        it "can remove all parents" do
          parent = make_node()
          other_parent = make_node()
          same_node = stub(:id => node.id)

          parenter = InheritanceManager.new(node)
          parenter.add_parent(parent)
          parenter.add_parent(other_parent)

          parenter = InheritanceManager.new(node)
          parenter.del_all_parents

          parenter = InheritanceManager.new(same_node)
          parenter.parent_ids.should be_empty
        end

        it "can return actual Node parent instances" do
          parent = make_node()
          InheritanceManager.new(node).add_parent(parent)
          InheritanceManager.new(node).parents.should include(parent)
        end

        it "can return actual Node child instances" do
          child = make_node()
          InheritanceManager.new(node).add_child(child)
          InheritanceManager.new(node).children.should include(child)
        end

        describe ".parents_of" do
          it "works in the same way as InheritanceManager.new(foo).parents" do
            parent = make_node()
            InheritanceManager.new(node).add_parent(parent)
            InheritanceManager.parents_of(node).should ==
              InheritanceManager.new(node).parents
          end
        end

        describe ".parent_ids_of" do
          it "works in the same way as InheritanceManager.new(foo).parent_ids" do
            parent = make_node()
            InheritanceManager.new(node).add_parent(parent)
            InheritanceManager.parent_ids_of(node).should ==
              InheritanceManager.new(node).parent_ids
          end
        end

        describe ".children_of" do
          it "works in the same way as InheritanceManager.new(foo).children" do
            child = make_node()
            InheritanceManager.new(node).add_child(child)
            InheritanceManager.children_of(node).should ==
              InheritanceManager.new(node).children
          end
        end

        describe ".parent_ids_of" do
          it "works in the same way as InheritanceManager.new(foo).parent_ids" do
            child = make_node()
            InheritanceManager.new(node).add_child(child)
            InheritanceManager.child_ids(node).should ==
              InheritanceManager.new(node).child_ids
          end
        end
      end

      describe "ancestors and descendants API" do

        def set_parent_nodes_of(node, options)
          parents = options.fetch(:as)
          parents.each do |parent|
            InheritanceManager.new(node).add_parent(parent)
          end
        end

        def set_child_nodes_of(node, options)
          children = options.fetch(:as)
          children.each do |child|
            InheritanceManager.new(node).add_child(child)
          end
        end

        subject { InheritanceManager.new(node) }

        describe "#ancestor_ids" do
          let(:parent1)   { make_node() }
          let(:parent2)   { make_node() }
          let(:ancestor1) { make_node() }
          let(:ancestor2) { make_node() }
          let(:ancestor3) { make_node() }

          before do
            set_parent_nodes_of(node, :as => [parent1, parent2])
            set_parent_nodes_of(parent1, :as => [ancestor1, ancestor2])
            set_parent_nodes_of(parent2, :as => [ancestor3, ancestor2])
          end

          it "contains the node's parents" do
            subject.ancestor_ids.should include(parent1.id, parent2.id)
          end

          it "contain each of the parent nodes ancestors" do
            subject.ancestor_ids.should include(ancestor1.id, ancestor2.id,
                                                ancestor3.id)
          end

          it "includes the GlobalNode" do
            subject.ancestor_ids.should include(global_node)
          end

          it "doesn't repeat elements" do
            ancestor_ids = subject.ancestor_ids
            ancestor_ids.to_a.uniq.size.should == ancestor_ids.size
          end
        end

        describe "#descendant_ids" do
          let(:child1)      { make_node() }
          let(:child2)      { make_node() }
          let(:descendant1) { make_node() }
          let(:descendant2) { make_node() }
          let(:descendant3) { make_node() }

          let(:global_node) { stub("Global Node") }

          before do
            set_child_nodes_of(node, :as => [child1, child2])
            set_child_nodes_of(child1, :as => [descendant1, descendant2])
            set_child_nodes_of(child2, :as => [descendant3, descendant2])

            AccessControl.stub(:global_node => global_node)
          end

          it "contains the node's children" do
            subject.descendant_ids.should include(child1.id, child2.id)
          end

          it "contain each of the child nodes descendants" do
            subject.descendant_ids.should include(descendant1.id,
                                                  descendant2.id,
                                                  descendant3.id)
          end

          it "doesn't include the GlobalNode" do
            subject.descendant_ids.should_not include(global_node)
          end

          it "doesn't repeat elements" do
            descendant_ids = subject.descendant_ids
            descendant_ids.to_a.uniq.size.should == descendant_ids.size
          end
        end

        describe "#ancestors" do
          it "returns Node instances" do
            parent = make_node()
            ancestor = make_node()
            set_parent_nodes_of(node, :as => [parent])
            set_parent_nodes_of(parent, :as => [ancestor])

            subject.ancestors.should include(parent, ancestor)
          end
        end

        describe "#descendants" do
          it "returns Node instances" do
            child = make_node()
            descendant = make_node()
            set_child_nodes_of(node, :as => [child])
            set_child_nodes_of(child, :as => [descendant])

            subject.descendants.should include(child, descendant)
          end
        end
      end
    end
  end
end
