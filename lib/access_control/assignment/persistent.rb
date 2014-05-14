require 'access_control/assignment'
require 'access_control/ids'
require 'sequel/plugins/tree'

module AccessControl
  class Assignment::Persistent < Sequel::Model(:ac_assignments)
    self.raise_on_save_failure = true

    class << self
      def propagate_to(assignments, node_id)
        propagate_descendants(ids_of(assignments), to_node_ids: node_id)
      end

      def propagate_to_descendants(assignments)
        propagate_descendants(ids_of(assignments))
      end

      def depropagate_from(assignments, node_id)
        assignments_to_depropagate = with_nodes(node_id).children_of(assignments)
        assignments_to_depropagate.each do |a|
          a.destroy
          destroy_children_of(a.id)
        end
      end

      def destroy_children_of(assignment_id)
        children_of(assignment_id).map do |persistent|
          persistent.destroy
          destroy_children_of(persistent.id)
        end
      end

    private

      def ids_of(assignments)
        if assignments.is_a?(Sequel::Dataset)
          assignments.select(:id)
        else
          filter(id: assignments.map(&:id)).select(:id)
        end
      end

      def child_node_ids_of(parent_node_ids)
        AccessControl.ac_parents.
          filter(parent_id: parent_node_ids).select(:child_id)
      end

      def propagate_descendants(source_ids, params={})
        to_node_ids = params[:to_node_ids]
        new_assignments = descend(source_ids, to_node_ids: to_node_ids)

        if new_assignments.count > 0
          propagate_descendants(new_assignments.select(:id))
        end
      end

      def descend(source_ids, params)
        combos = combinations_of(source_ids, to_node_ids: params[:to_node_ids])

        if count = combos.count
          # Here we assume that all generated ids are consecutive in all cases,
          # and the Sequel adapter in use is capable of providing the id of the
          # first inserted row.  This is generally true in MySQL when InnoDB is
          # the engine of the table, and the innodb_autoinc_lock_mode is set to
          # 0 (traditional) or 1 (consecutive).
          id = import([:parent_id, :role_id, :principal_id, :node_id], combos)

          filter(id: id...id + count)
        else
          invert
        end
      end

      def combinations_of(source_ids, params)
        filter_params = { :ac_assignments__id => source_ids }

        child_node_ids = params[:to_node_ids]
        if child_node_ids
          filter_params[:ac_parents__child_id] = child_node_ids
        end

        select(:ac_assignments__id, :role_id, :principal_id,
               :ac_parents__child_id).
          join_table(:inner, :ac_parents,
                     :ac_assignments__node_id => :ac_parents__parent_id).
          filter(filter_params)
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

    subset(:real,               {:parent_id => nil})
    subset(:effective, Sequel.~({:parent_id => nil}))
  end
end
