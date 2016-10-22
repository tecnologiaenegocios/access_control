module AccessControl
  class RolePropagation

    def self.propagate!(node, parents = nil)
      new(node, parents).propagate!
    end

    def self.depropagate!(node, parents = nil)
      new(node, parents).depropagate!
    end

    attr_reader :node
    def initialize(node, node_parents = nil)
      @node         = node
      @node_parents = node_parents
    end

    def propagate!
      Assignment::Persistent.propagate_to(relevant_assignments, node.id)
    end

    def depropagate!
      Assignment::Persistent.depropagate_from(relevant_assignments, node.id)
    end

    attr_writer :relevant_assignments
    def relevant_assignments
      @relevant_assignments ||=
        if node_parents.any?
          Assignment::Persistent.with_nodes(node_parents)
        else
          []
        end
    end

    def node_parents
      @node_parents ||= Node::InheritanceManager.parents_of(node)
    end
  end
end
