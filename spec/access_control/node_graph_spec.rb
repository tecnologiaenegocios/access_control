require 'spec_helper'
require 'access_control/node_graph'

module AccessControl
  describe NodeGraph do
    let(:graph) do
      NodeGraph.new { |result| result.map { |row| node(row[:linkid]) } }
    end

    let(:network) do
      {
        # Simple multi-levels
        1 => [2],
        2 => [3],

        # Cycle
        10 => [11],
        11 => [12],
        12 => [10],
        13 => [10],

        # Multiple children
        100 => [101, 102],

        # Multiple parents
        1001 => [1000],
        1002 => [1000],

        # Multiple parents/children multi-level
        10000 => [10001, 10002],
        10001 => [10003, 10004],
        10005 => [10006],
        10006 => [10007],
        10008 => [10007],
      }
    end

    let(:node_type) { Struct.new(:id) }

    before do
      table = AccessControl.db[:ac_parents]

      network.each do |parent_id, children_ids|
        children_ids.each do |child_id|
          table.insert(parent_id: parent_id, child_id: child_id)
        end
      end
    end

    def node(id)
      node_type.new(id)
    end

    describe "self path" do
      it "can properly report self paths" do
        graph.reachable_from(node(1)).should include(node(1))
        graph.reaching(node(1)).should include(node(1))
      end
    end

    describe "simple multi-level" do
      it "can properly report immediate child nodes" do
        graph.reachable_from(node(1)).should include(node(2))
      end

      it "can properly report nested child nodes" do
        graph.reachable_from(node(1)).should include(node(3))
      end

      it "can properly report immediate parent nodes" do
        graph.reaching(node(2)).should include(node(1))
      end

      it "can properly report nested parent nodes" do
        graph.reaching(node(3)).should include(node(1))
      end

      it "reports direction properly" do
        graph.reaching(node(1)).should include_only(node(1))
        graph.reaching(node(2)).should_not include(node(3))
        graph.reachable_from(node(2)).should_not include(node(1))
        graph.reachable_from(node(3)).should include_only(node(3))
      end
    end

    describe "cycle" do
      it "can properly report child nodes on cycles" do
        graph.reachable_from(node(10)).should include(node(11))
        graph.reachable_from(node(10)).should include(node(12))
        graph.reachable_from(node(11)).should include(node(10))
        graph.reachable_from(node(11)).should include(node(12))
        graph.reachable_from(node(12)).should include(node(10))
        graph.reachable_from(node(12)).should include(node(11))
      end

      it "can properly report parent nodes on cycles" do
        graph.reaching(node(10)).should include(node(11))
        graph.reaching(node(10)).should include(node(12))
        graph.reaching(node(11)).should include(node(10))
        graph.reaching(node(11)).should include(node(12))
        graph.reaching(node(12)).should include(node(10))
        graph.reaching(node(12)).should include(node(11))
      end

      it "propagates the cycle to upper nodes" do
        graph.reachable_from(node(13)).should include(node(10))
        graph.reachable_from(node(13)).should include(node(11))
        graph.reachable_from(node(13)).should include(node(12))
      end

      specify "the cycle should not itself include upper nodes" do
        graph.reaching(node(13)).should_not include(node(10))
        graph.reaching(node(13)).should_not include(node(11))
        graph.reaching(node(13)).should_not include(node(12))
      end
    end

    describe "multiple parents/children" do
      it "allows multiple children" do
        graph.reachable_from(node(100)).should include(node(101))
        graph.reachable_from(node(100)).should include(node(102))
      end

      specify "all children will be connected to their common parent" do
        graph.reaching(node(101)).should include(node(100))
        graph.reaching(node(102)).should include(node(100))
      end

      specify "children won't be connected themselves" do
        graph.reaching(node(102)).should_not include(node(101))
      end

      it "allows multiple parents" do
        graph.reaching(node(1000)).should include(node(1001))
        graph.reaching(node(1000)).should include(node(1002))
      end

      specify "all parents will be connected to their common child" do
        graph.reachable_from(node(1001)).should include(node(1000))
        graph.reachable_from(node(1002)).should include(node(1000))
      end

      specify "parents won't be connected themselves" do
        graph.reachable_from(node(1002)).should_not include(node(1001))
      end

      it "allows multiple children and grand-children" do
        graph.reachable_from(node(10000)).should include(node(10001))
        graph.reachable_from(node(10000)).should include(node(10002))
        graph.reachable_from(node(10000)).should include(node(10003))
        graph.reachable_from(node(10000)).should include(node(10004))

        graph.reaching(node(10004)).should include(node(10000))
        graph.reaching(node(10004)).should include(node(10001))
      end

      specify "leaf nodes will not be reported as parents" do
        graph.reachable_from(node(10002)).should include_only(node(10002))
        graph.reachable_from(node(10004)).should include_only(node(10004))
      end

      it "allows multiple parents and grand-parents" do
        graph.reaching(node(10007)).should include(node(10005))
        graph.reaching(node(10007)).should include(node(10006))
        graph.reaching(node(10007)).should include(node(10008))
      end

      specify "root nodes will not be reported as children" do
        graph.reaching(node(10005)).should include_only(node(10005))
      end
    end
  end
end
