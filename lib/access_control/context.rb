require 'access_control/util'
require 'access_control/parenter'

module AccessControl
  class Context

    def initialize(item_or_collection)
      @collection = Util.make_set_from_args(item_or_collection)
    end

    def nodes
      @collection.inject(Set.new) do |nodes, item|
        nodes | self.class.extract_nodes(item)
      end
    end

  private

    def self.extract_nodes item
      unless item.is_a?(Node)
        args = item.ac_node || Parenter.new(item).get.map(&:ac_node)
      else
        args = item
      end
      Util.make_set_from_args(args)
    end

  end
end
