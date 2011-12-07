require 'access_control/util'
require 'access_control/parenter'

module AccessControl
  class Context

    def initialize(item_or_collection)
      @collection = Array(item_or_collection)
    end

    def nodes
      Util.flat_set(@collection) { |item| nodes_relevant_to(item) }
    end

  private

    def nodes_relevant_to(item)
      if owned_node = node_owned_by(item)
        Set[owned_node]
      else
        item_parents = Parenter.new(item).get
        Util.flat_set(item_parents) { |parent| nodes_relevant_to(parent) }
      end
    end

    def node_owned_by(item)
      item.is_a?(Node) ? item : item.ac_node
    end
  end
end
