module AccessControl
  class RolePropagation

    attr_reader :node
    def initialize(node, node_parents = nil)
      @node         = node
      @node_parents = node_parents
    end

    def propagate!
      Assignment::Persistent.propagate_all(relevant_assignments,
                                           :node_id => node.id)
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
