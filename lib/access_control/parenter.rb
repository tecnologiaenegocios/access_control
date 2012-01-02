require 'access_control/db'
require 'access_control/exceptions'
require 'access_control/node'
require 'access_control/behavior'

module AccessControl
  class Parenter
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

    def parent_ids
      parent_set.map { |r| r[:parent_id] }
    end

    def child_ids
      child_set.map { |r| r[:child_id] }
    end

  private

    def db
      AccessControl.db[:ac_parents]
    end

    def parent_set
      db.filter(:child_id => node.id)
    end

    def child_set
      db.filter(:parent_id => node.id)
    end

  end
end
