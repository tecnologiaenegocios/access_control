require 'access_control/db'
require 'access_control/util'

module AccessControl
  class NodeGraph
    def initialize(&wrapper)
      @wrapper = wrapper || -> result { result.map { |row| row[:linkid] } }
    end

    def reaching(child_node)
      wrap(reaching_dataset(child_node))
    end

    def reachable_from(parent_node)
      wrap(reachable_from_dataset(parent_node))
    end

  private

    def wrap(dataset)
      @wrapper.call(dataset)
    end

    def reaching_dataset(child_node)
      reversed.filter(origid: key(child_node)).select(:linkid)
    end

    def reachable_from_dataset(parent_node)
      direct.filter(origid: key(parent_node)).select(:linkid)
    end

    def direct
      AccessControl.db[:ac_paths].filter(latch: 'breadth_first')
    end

    def reversed
      AccessControl.db[:ac_reversed_paths].filter(latch: 'breadth_first')
    end

    def key(value)
      Util.ids_for_hash_condition(value)
    end
  end
end
