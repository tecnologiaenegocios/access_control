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

    def self.child_ids_of(*args)
      self.new(*args).child_ids
    end

    def self.ancestors_of(*args)
      self.new(*args).ancestors
    end

    def self.ancestor_ids_of(*args)
      self.new(*args).ancestor_ids
    end

    def self.descendants_of(*args)
      self.new(*args).descendants
    end

    def self.descendant_ids_of(*args, &block)
      self.new(*args).descendant_ids(&block)
    end

    attr_reader :node_id

    def initialize(node_or_node_id)
      if node_or_node_id.is_a?(Fixnum)
        @node_id = node_or_node_id
      else
        # Implicitly considering the argument a real node
        @node = node_or_node_id
        @node_id = node_or_node_id.id
      end
    end

    def add_parent(parent)
      check_add_parent_permissions(node, parent)
      db << { :child_id => node_id, :parent_id => parent.id }
    end

    def add_child(child)
      check_add_parent_permissions(child, node)
      db << { :child_id => child.id, :parent_id => node_id }
    end

    def del_parent(parent)
      check_del_parent_permissions(node, parent)
      parent_set.filter(:parent_id => parent.id).delete
    end

    def del_child(child)
      check_del_parent_permissions(child, node)
      child_set.filter(:child_id => child.id).delete
    end

    def del_all_parents_with_checks
      parent_set.each do |row|
        parent_id = row[:parent_id]
        check_del_parent_permissions(node, Node.fetch(parent_id))
        parent_set.filter(:parent_id => parent_id).delete
      end
    end

    def del_all_children
      child_set.delete
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

    def parent_ids
      parent_ids_by_id(node_id)
    end

    def child_ids
      child_ids_by_id(node_id)
    end

    def ancestor_ids
      recurse_ancestor_ids([node_id])
    end

    def descendant_ids(&block)
      recurse_descendant_ids([node_id], &block)
    end

  private

    def db
      AccessControl.ac_parents
    end

    def node
      @node ||= Node.fetch(@node_id)
    end

    def parent_ids_by_id(id)
      Set.new parent_set(id).select_map(:parent_id)
    end

    def child_ids_by_id(id)
      Set.new child_set(id).select_map(:child_id)
    end

    def parent_set(id=node_id)
      db.filter(:child_id => id)
    end

    def child_set(id=node_id)
      db.filter(:parent_id => id)
    end

    def recurse_ancestor_ids(ids)
      immediate_parent_ids = parent_ids_by_id(ids)

      if immediate_parent_ids.any?
        grand_parent_and_ancestor_ids =
          recurse_ancestor_ids(Array(immediate_parent_ids))
        immediate_parent_ids.merge(grand_parent_and_ancestor_ids)
      else
        immediate_parent_ids
      end
    end

    def recurse_descendant_ids(ids, &block)
      immediate_child_ids =
        grouped_by_parent_ids(ids).
        each_with_object(Set.new) do |(parent_id, child_ids), set|
          block.call(parent_id, child_ids) if block_given?
          set.merge(child_ids)
        end

      if immediate_child_ids.any?
        grand_child_and_descendant_ids =
          recurse_descendant_ids(Array(immediate_child_ids), &block)
        immediate_child_ids.merge(grand_child_and_descendant_ids)
      else
        immediate_child_ids
      end
    end

    def grouped_by_parent_ids(ids)
      rows = db.filter(:parent_id => ids).select(:parent_id, :child_id).to_a
      rows.group_by { |row| row[:parent_id] }.map do |parent_id, subrows|
        [parent_id, subrows.map{|sr| sr[:child_id]}]
      end
    end

    def check_add_parent_permissions(target, parent)
      AccessControl.manager.can!(create_permissions(target), parent)
    end

    def check_del_parent_permissions(target, parent)
      AccessControl.manager.can!(destroy_permissions(target), parent)
    end

    def create_permissions(target)
      target.securable_class.permissions_required_to_create
    end

    def destroy_permissions(target)
      target.securable_class.permissions_required_to_destroy
    end
  end
end
