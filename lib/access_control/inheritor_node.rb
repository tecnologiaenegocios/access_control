require 'active_support'
require 'delegate'
require 'access_control/parenter'

module AccessControl

  def self.InheritorNode(object)
    if object.kind_of?(InheritorNode)
      object
    else
      InheritorNode.new(object)
    end
  end

  class InheritorNode < SimpleDelegator

    if instance_methods.map(&:to_sym).include?(:id)
      undef :id
    end

    def initialize(node)
      __setobj__ node
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
        Util.compact_flat_set(parents) do |parent|
          parent_node = AccessControl::InheritorNode(parent)
          parent_node.ancestors << parent
        end
      end
    end

  private

    def node
      __getobj__
    end

    def guard_against_missing_inheritance
      if Inheritance.recognizes?(securable)
        yield
      else
        Set.new
      end
    end

  end
end
