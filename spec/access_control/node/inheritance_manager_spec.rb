# vim: fdm=marker
require 'spec_helper'
require 'access_control/node/inheritance_manager'

module AccessControl
  class Node
    describe InheritanceManager do

      def make_node(name = nil)
        @ids ||= Enumerator.new do |yielder|
          n = 0
          loop { yielder.yield(n+=1) }
        end

        id   = @ids.next
        name ||= "Node #{id}"
        node = stub(name, :id => id)
        all_nodes[id] = node
        node
      end

      let(:all_nodes) { Hash.new }
      let(:node)      { make_node }
      let(:node_id)   { node.id }

      describe "on initialization" do
        it "accepts a node instance, and uses its ID internally" do
          imanager = InheritanceManager.new(node)
          imanager.node_id.should == node_id
        end

        it "accepts a number, and considers it as being the ID of the node" do
          imanager = InheritanceManager.new(node_id)
          imanager.node_id.should == node_id
        end
      end

      before do
        Node.stub(:fetch_all) { |ids| all_nodes.values_at(*ids) }
        Node.stub(:fetch) { |id| all_nodes[id] or raise "Not found" }
      end

      describe "immediate parents and children API" do
        it "can add a new parent and persist it" do
          parent = make_node()
          InheritanceManager.new(node_id).add_parent(parent)

          InheritanceManager.new(node_id).parent_ids.
            should include(parent.id)
        end

        it "can add a new child and persist it" do
          child = make_node()
          InheritanceManager.new(node_id).add_child(child)

          InheritanceManager.new(node_id).child_ids.should include(child.id)
        end

        it "can remove an existing parent and persist it" do
          parent = make_node()
          other_parent = make_node()

          imanager = InheritanceManager.new(node_id)
          imanager.add_parent(parent)
          imanager.add_parent(other_parent)

          imanager = InheritanceManager.new(node_id)
          imanager.del_parent(parent)

          ids = InheritanceManager.new(node_id).parent_ids
          ids.should include(other_parent.id)
          ids.should_not include(parent.id)
        end

        it "can remove existing child and persist it" do
          child = make_node()
          other_child = make_node()

          imanager = InheritanceManager.new(node_id)
          imanager.add_child(child)
          imanager.add_child(other_child)

          imanager = InheritanceManager.new(node_id)
          imanager.del_child(child)

          ids = InheritanceManager.new(node_id).child_ids
          ids.should include(other_child.id)
          ids.should_not include(child.id)
        end

        it "can remove all parents" do
          parent = make_node()
          other_parent = make_node()

          parenter = InheritanceManager.new(node_id)
          parenter.add_parent(parent)
          parenter.add_parent(other_parent)

          parenter = InheritanceManager.new(node_id)
          parenter.del_all_parents

          parenter.parent_ids.should be_empty
        end

        it "can remove all children" do
          child = make_node()
          other_child = make_node()

          parenter = InheritanceManager.new(node_id)
          parenter.add_child(child)
          parenter.add_child(other_child)

          parenter = InheritanceManager.new(node_id)
          parenter.del_all_children

          parenter.child_ids.should be_empty
        end

        it "can return actual Node parent instances" do
          parent = make_node()
          InheritanceManager.new(node_id).add_parent(parent)
          InheritanceManager.new(node_id).parents.should include(parent)
        end

        it "can return actual Node child instances" do
          child = make_node()
          InheritanceManager.new(node_id).add_child(child)
          InheritanceManager.new(node_id).children.should include(child)
        end

        describe ".parents_of" do
          it "works like InheritanceManager.new(foo).parents" do
            parent = make_node()
            InheritanceManager.new(node_id).add_parent(parent)
            InheritanceManager.parents_of(node_id).should ==
              InheritanceManager.new(node_id).parents
          end
        end

        describe ".parent_ids_of" do
          it "works like InheritanceManager.new(foo).parent_ids" do
            parent = make_node()
            InheritanceManager.new(node_id).add_parent(parent)
            InheritanceManager.parent_ids_of(node_id).should ==
              InheritanceManager.new(node_id).parent_ids
          end
        end

        describe ".children_of" do
          it "works like InheritanceManager.new(foo).children" do
            child = make_node()
            InheritanceManager.new(node_id).add_child(child)
            InheritanceManager.children_of(node_id).should ==
              InheritanceManager.new(node_id).children
          end
        end

        describe ".child_ids_of" do
          it "works like InheritanceManager.new(foo).child_ids" do
            child = make_node()
            InheritanceManager.new(node_id).add_child(child)
            InheritanceManager.child_ids_of(node_id).should ==
              InheritanceManager.new(node_id).child_ids
          end
        end
      end

      describe "ancestors and descendants API" do

        def set_parent_nodes_of(node, options)
          imanager = InheritanceManager.new(node.id)
          parents  = options.fetch(:as)

          parents.each do |parent|
            imanager.add_parent(parent)
          end
        end

        def set_child_nodes_of(node, options)
          imanager = InheritanceManager.new(node.id)
          children = options.fetch(:as)

          children.each do |child|
            imanager.add_child(child)
          end
        end

        let(:inheritance_manager) { InheritanceManager.new(node_id) }

        describe "#ancestor_ids" do
          let!(:parent1)   { make_node() }
          let!(:parent2)   { make_node() }
          let!(:ancestor1) { make_node() }
          let!(:ancestor2) { make_node() }
          let!(:ancestor3) { make_node() }

          subject { inheritance_manager.ancestor_ids }

          before do
            set_parent_nodes_of(node, :as => [parent1, parent2])
            set_parent_nodes_of(parent1, :as => [ancestor1, ancestor2])
            set_parent_nodes_of(parent2, :as => [ancestor3, ancestor2])
          end

          it "includes the node's immediate parents ids" do
            immediate_parents_ids = [parent1, parent2].map(&:id)
            subject.should include(*immediate_parents_ids)
          end

          it "includes the ids of the parents of the node's parents" do
            second_degree_parents_ids = [ancestor1, ancestor2, ancestor3].map(&:id)
            subject.should include(*second_degree_parents_ids)
          end

          it "doesn't include the IDs of unrelated nodes" do
            unrelated_node = make_node()
            subject.should_not include(unrelated_node.id)
          end
        end

        describe "#descendant_ids" do
          let!(:child1)      { make_node() }
          let!(:child2)      { make_node() }
          let!(:descendant1) { make_node() }
          let!(:descendant2) { make_node() }
          let!(:descendant3) { make_node() }

          subject { inheritance_manager.descendant_ids }

          before do
            set_child_nodes_of(node, :as => [child1, child2])
            set_child_nodes_of(child1, :as => [descendant1, descendant2])
            set_child_nodes_of(child2, :as => [descendant3, descendant2])
          end

          it "includes the node's immediate children ids" do
            immediate_children_ids = [child1, child2].map(&:id)
            subject.should include(*immediate_children_ids)
          end

          it "includes the ids of the children of the node's children" do
            second_degree_children_ids =
              [descendant1, descendant2, descendant3].map(&:id)
            subject.should include(*second_degree_children_ids)
          end

          it "doesn't include the IDs of unrelated nodes" do
            unrelated_node = make_node()
            subject.should_not include(unrelated_node.id)
          end

          context "when it receives a block" do
            describe "iteration by level" do
              def yielded_values
                @yielded_values ||= begin
                  hash = Hash.new
                  inheritance_manager.descendant_ids do |node_id, children_ids|
                    hash[node_id] = children_ids
                  end
                  hash
                end
              end

              it "yields the node and its children to the block" do
                yielded_values.should have_key(node.id)
                yielded_values[node.id].should include_only(child1.id, child2.id)
              end

              it "yields the children that are parents, along with their children" do
                yielded_values.should have_key(child1.id)
                yielded_values[child1.id].should include_only(descendant1.id,
                                                              descendant2.id)

                yielded_values.should have_key(child2.id)
                yielded_values[child2.id].should include_only(descendant3.id,
                                                              descendant2.id)
              end

              it "doesn't yield nodes that have no children" do
                leaf_nodes = [descendant1, descendant2, descendant3]
                leaf_nodes.each do |leaf_node|
                  yielded_values.should_not have_key(leaf_node.id)
                end
              end
            end

            describe "monotonicity of depth in block calls" do
              let!(:descendant4) { make_node() }
              let!(:descendant5) { make_node() }
              let!(:descendant6) { make_node() }

              before do
                set_child_nodes_of(descendant1, :as => [descendant4])
                set_child_nodes_of(descendant2, :as => [descendant5, descendant6])
              end

              def yield_parents
                @yielded_parents ||= begin
                  arr = []
                  inheritance_manager.descendant_ids do |node_id, children_ids|
                    arr << node_id
                  end
                  arr
                end
              end

              it "calls the block as many times as there are different "\
                 "parents with some child" do
                yielded_parents = yield_parents()
                yielded_parents.size.should == 5
              end

              it "preserves the order of depth as calls are performed" do
                yielded_parents = yield_parents()

                levels = [
                  [node.id],                        # first level
                  [child1.id, child2.id],           # second level
                  [descendant1.id, descendant2.id]  # third level
                ]

                levels.each do |expected_parents|
                  head = yielded_parents.shift(expected_parents.size)
                  head.should include_only(*expected_parents)
                end
              end
            end
          end
        end

        describe "#ancestors" do
          let(:node_ancestors) { inheritance_manager.ancestors }

          let!(:parent) { make_node() }
          let!(:ancestor) { make_node() }

          before do
            set_parent_nodes_of(node, :as => [parent])
            set_parent_nodes_of(parent, :as => [ancestor])
          end

          it "include the node's immediate parents" do
            node_ancestors.should include(parent)
          end

          it "include the parents of the node's parents" do
            node_ancestors.should include(ancestor)
          end

          it "doesn't include unrelated nodes" do
            random_node = make_node()
            node_ancestors.should_not include(random_node)
          end
        end

        describe "#descendants" do
          it "returns Node instances" do
            child = make_node()
            descendant = make_node()
            set_child_nodes_of(node, :as => [child])
            set_child_nodes_of(child, :as => [descendant])

            inheritance_manager.descendants.should include_only(child,
                                                                descendant)
          end
        end

        describe "module methods for ancestors" do
          before do
            parent = make_node()
            ancestor = make_node()
            set_parent_nodes_of(node, :as => [parent])
            set_parent_nodes_of(parent, :as => [ancestor])
          end

          describe ".ancestors_of" do
            it "works like InheritanceManager.new(foo).parents" do
              InheritanceManager.ancestors_of(node_id).should ==
                InheritanceManager.new(node_id).ancestors
            end
          end

          describe ".ancestor_ids_of" do
            it "works like InheritanceManager.new(foo).ancestor_ids" do
              InheritanceManager.ancestor_ids_of(node_id).should ==
                InheritanceManager.new(node_id).ancestor_ids
            end
          end
        end

        describe "module methods for descendants" do
          before do
            child = make_node()
            descendant = make_node()
            set_child_nodes_of(node, :as => [child])
            set_child_nodes_of(child, :as => [descendant])
          end

          describe ".descendants_of" do
            it "works like InheritanceManager.new(foo).children" do
              InheritanceManager.descendants_of(node_id).should ==
                InheritanceManager.new(node_id).descendants
            end
          end

          describe ".decendant_ids_of" do
            it "works like InheritanceManager.new(foo).descendant_ids" do
              InheritanceManager.descendant_ids_of(node_id).should ==
                InheritanceManager.new(node_id).descendant_ids
            end

            it "can accept a block, just like the instance method" do
              descendants = Set.new
              InheritanceManager.descendant_ids_of(node_id) do |p, children|
                descendants.merge(children)
              end
              descendants.should ==
                InheritanceManager.new(node_id).descendant_ids
            end
          end
        end
      end
    end
  end
end
