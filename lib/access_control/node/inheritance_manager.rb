require 'active_support'
require 'delegate'
require 'access_control/node'

module AccessControl
  class Node::InheritanceManager
    def self.parents_of(*args)
      self.new(*args).parents
    end

    def self.children_of(*args)
      self.new(*args).children
    end

    def self.parent_ids_of(*args)
      self.new(*args).parent_ids
    end

    def self.child_ids(*args)
      self.new(*args).child_ids
    end

    attr_reader :node

    def initialize(node)
      @node = node
    end

    def add_parent(parent)
      db << { :child_id => node.id, :parent_id => parent.id }
    end

    def add_child(child)
      db << { :child_id => child.id, :parent_id => node.id }
    end

    def del_parent(parent)
      parent_set.filter(:parent_id => parent.id).delete
    end

    def del_child(child)
      child_set.filter(:child_id => child.id).delete
    end

    def del_all_parents
      parent_set.delete
    end

    def parents
      Node.fetch_all(parent_ids)
    end

    def children
      Node.fetch_all(child_ids)
    end

    def ancestors
      Node.fetch_all(ancestor_ids)
    end

    def descendants
      Node.fetch_all(descendant_ids)
    end

    def parent_ids(id=node.id)
      Set.new parent_set(id).map { |r| r[:parent_id] }
    end

    def child_ids(id=node.id)
      Set.new child_set(id).map { |r| r[:child_id] }
    end

    def ancestor_ids(id=node.id)
      parent_ids(id).each_with_object(default_ancestor_set) do |parent_id, set|
        set << parent_id
        set.merge(ancestor_ids(parent_id))
      end
    end

    def descendant_ids(id=node.id)
      child_ids(id).each_with_object(Set.new) do |child_id, set|
        set << child_id
        set.merge(descendant_ids(child_id))
      end
    end

  private

    def db
      AccessControl.ac_parents
    end

    def parent_set(id=node.id)
      db.filter(:child_id => id)
    end

    def child_set(id=node.id)
      db.filter(:parent_id => id)
    end

    def default_ancestor_set
      Set[AccessControl.global_node]
    end
  end
end
