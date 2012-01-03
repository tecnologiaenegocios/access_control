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
      let(:global_node) { stub_model(Node) }

      before do
        all_nodes[global_node.id] = global_node
        Node.stub(:fetch_all) { |ids| ids.map{|id| all_nodes[id]} }
        AccessControl.stub(:global_node_id => global_node.id)
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
          it "works like InheritanceManager.new(foo).parents" do
            parent = make_node()
            InheritanceManager.new(node).add_parent(parent)
            InheritanceManager.parents_of(node).should ==
              InheritanceManager.new(node).parents
          end
        end

        describe ".parent_ids_of" do
          it "works like InheritanceManager.new(foo).parent_ids" do
            parent = make_node()
            InheritanceManager.new(node).add_parent(parent)
            InheritanceManager.parent_ids_of(node).should ==
              InheritanceManager.new(node).parent_ids
          end
        end

        describe ".children_of" do
          it "works like InheritanceManager.new(foo).children" do
            child = make_node()
            InheritanceManager.new(node).add_child(child)
            InheritanceManager.children_of(node).should ==
              InheritanceManager.new(node).children
          end
        end

        describe ".child_ids_of" do
          it "works like InheritanceManager.new(foo).child_ids" do
            child = make_node()
            InheritanceManager.new(node).add_child(child)
            InheritanceManager.child_ids_of(node).should ==
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

        let(:inheritance_manager) { InheritanceManager.new(node) }

        describe "#ancestor_ids" do
          let!(:parent1)   { make_node() }
          let!(:parent2)   { make_node() }
          let!(:parent3)   { make_node() }
          let!(:ancestor1) { make_node() }
          let!(:ancestor2) { make_node() }
          let!(:ancestor3) { make_node() }

          subject { inheritance_manager.ancestor_ids }

          before do
            set_parent_nodes_of(node, :as => [parent1, parent2])
            set_parent_nodes_of(parent1, :as => [ancestor1, ancestor2])
            set_parent_nodes_of(parent2, :as => [ancestor3, ancestor2])
          end

          it { should include_only(
            parent1.id,
            parent2.id,
            ancestor1.id,
            ancestor2.id,
            ancestor3.id,
            global_node.id
          ) }
        end

        describe "#descendant_ids" do
          let!(:child1)      { make_node() }
          let!(:child2)      { make_node() }
          let!(:child3)      { make_node() }
          let!(:descendant1) { make_node() }
          let!(:descendant2) { make_node() }
          let!(:descendant3) { make_node() }

          subject { inheritance_manager.descendant_ids }

          before do
            set_child_nodes_of(node, :as => [child1, child2])
            set_child_nodes_of(child1, :as => [descendant1, descendant2])
            set_child_nodes_of(child2, :as => [descendant3, descendant2])

            AccessControl.stub(:global_node => global_node)
          end

          it { should include_only(
            child1.id,
            child2.id,
            descendant1.id,
            descendant2.id,
            descendant3.id
          ) }
        end

        describe "#ancestors" do
          it "returns Node instances" do
            parent = make_node()
            ancestor = make_node()
            set_parent_nodes_of(node, :as => [parent])
            set_parent_nodes_of(parent, :as => [ancestor])

            inheritance_manager.ancestors.should include_only(
              parent,
              ancestor,
              global_node
            )
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
              InheritanceManager.ancestors_of(node).should ==
                InheritanceManager.new(node).ancestors
            end
          end

          describe ".ancestor_ids_of" do
            it "works like InheritanceManager.new(foo).ancestor_ids" do
              InheritanceManager.ancestor_ids_of(node).should ==
                InheritanceManager.new(node).ancestor_ids
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
              InheritanceManager.descendants_of(node).should ==
                InheritanceManager.new(node).descendants
            end
          end

          describe ".decendant_ids_of" do
            it "works like InheritanceManager.new(foo).descendant_ids" do
              InheritanceManager.descendant_ids_of(node).should ==
                InheritanceManager.new(node).descendant_ids
            end
          end
        end
      end
    end
  end
end
