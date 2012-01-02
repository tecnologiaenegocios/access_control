require 'access_control/util'

module AccessControl
  class Context

    attr_reader :nodes
    def initialize(item_or_collection)
      collection = Array(item_or_collection)
      @nodes     = Util.flat_set(collection, &method(:nodes_relevant_to))
    end

  private

    def nodes_relevant_to(item)
      if owned_node = AccessControl::Node(item)
        Set[owned_node]
      else
        item_parents = Parenter.parents_of(item)
        Util.flat_set(item_parents) { |parent| nodes_relevant_to(parent) }
      end
    end

  end
end
