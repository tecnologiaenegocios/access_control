require 'access_control/assignment'
require 'access_control/ids'
require 'sequel/plugins/tree'

module AccessControl
  class Assignment::Persistent < Sequel::Model(:ac_assignments)
    plugin :tree, :key => :parent_id

    self.raise_on_save_failure = true

    class << self
      def propagate_all(assignments, node_id)
        parent_ids = propagate_to(assignments.map(&:id), node_id)
        parent_ids_by_level = { node_id => parent_ids }

        im = Node::InheritanceManager.new(node_id)
        im.descendant_ids do |parent_node_id, child_node_ids|
          parent_ids = parent_ids_by_level[parent_node_id]
          next_parent_ids = propagate_to(parent_ids, child_node_ids)

          child_node_ids.each do |node_id|
            arr = (parent_ids_by_level[node_id] ||= [])
            arr.concat(next_parent_ids)
          end
        end
      end

      def depropagate_all(assignments)
      end

    private

      def propagate_to(ids, node_ids)
        import(
          [:parent_id, :role_id, :principal_id, :node_id],
          select(:ac_assignments__id, :role_id, :principal_id, :ac_nodes__id).
          from(:ac_assignments, :ac_nodes).
          filter(:ac_assignments__id => ids, :ac_nodes__id => node_ids)
        )
        filter(:node_id => node_ids, :parent_id => ids).select_map(:id)
      end
    end

    def_dataset_method :with_nodes do |nodes|
      node_ids = Util.ids_for_hash_condition(nodes)
      filter :node_id => Node::Persistent.column_dataset(:id, node_ids)
    end

    def_dataset_method :with_roles do |roles|
      role_ids = Util.ids_for_hash_condition(roles)
      filter :role_id => Role::Persistent.column_dataset(:id, role_ids)
    end

    def_dataset_method :assigned_to do |principals|
      principal_ids = Util.ids_for_hash_condition(principals)
      dataset = Principal::Persistent.column_dataset(:id, principal_ids)
      filter :principal_id => dataset
    end

    def_dataset_method :assigned_on do |nodes, principals|
      with_nodes(nodes).assigned_to(principals)
    end

    def_dataset_method :overlapping do |roles_ids, principals_ids, nodes_ids|
      real.with_roles(roles_ids).assigned_on(nodes_ids, principals_ids)
    end

    def_dataset_method :children_of do |assignment|
      assignment_id = Util.ids_for_hash_condition(assignment)
      filter(:parent_id => assignment_id)
    end

    subset(:real,       {:parent_id => nil})
    subset(:effective, ~{:parent_id => nil})
  end
end
