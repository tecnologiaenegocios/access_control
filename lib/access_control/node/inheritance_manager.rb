require 'active_support'
require 'delegate'
require 'access_control/parenter'
require 'access_control/node'

module AccessControl

  class Node::InheritanceManager

    attr_reader :node
    def initialize(node)
      @node = node
    end

    def parents
      guard_against_missing_inheritance do
        Parenter.parent_nodes_of(node.securable)
      end
    end

    def securable_parents
      guard_against_missing_inheritance do
        Parenter.parents_of(node.securable)
      end
    end

    def ancestors(filter = nil)
      filter ||= proc { true }

      guard_against_missing_inheritance do
        filtered_parents = parents.select(&filter)

        Util.compact_flat_set(filtered_parents) do |parent_node|
          parent_node.ancestors(filter)
        end
      end
    end

  private

    def guard_against_missing_inheritance
      if Inheritance.recognizes?(node.securable)
        yield
      else
        Set.new
      end
    end

  end
end
