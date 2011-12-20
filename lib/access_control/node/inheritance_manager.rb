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

    def ancestors
      guard_against_missing_inheritance do
        ancestors = Util.compact_flat_set(parents, &:ancestors)
        ancestors.add(AccessControl.global_node)
      end
    end

    def filtered_ancestors(recursability_test)
      recursability_test = recursability_test.to_proc

      parents.each_with_object(Set.new) do |parent, ancestors_set|
        ancestors_set.add(parent)

        recursable_parent = inheritance_aware?(parent) &&
                              recursability_test.call(parent)

        if recursable_parent
          manager          = self.class.new(parent)
          parent_ancestors = manager.filtered_ancestors(recursability_test)
          ancestors_set.merge(parent_ancestors)
        end
      end
    end

  private

    def guard_against_missing_inheritance
      if inheritance_aware?(node)
        yield
      else
        Set.new
      end
    end

    def inheritance_aware?(node)
      Inheritance.recognizes?(node.securable)
    end
  end
end
