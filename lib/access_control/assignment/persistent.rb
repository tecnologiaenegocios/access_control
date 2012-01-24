require 'access_control/assignment'
require 'access_control/ids'
require 'sequel/plugins/tree'

module AccessControl
  class Assignment::Persistent < Sequel::Model(:ac_assignments)
    self.raise_on_save_failure = true

    class << self
      def propagate_to(assignments, node_id)
        propagate_descendants(ids_of(assignments),
                              :to        => node_id,
                              :scoped_by => node_id)
      end

      def propagate_to_descendants(assignments, node_id)
        propagate_descendants(ids_of(assignments),
                              :to => child_node_ids_of(node_id))
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
          assignments.select_map(:id)
        else
          assignments.map(&:id)
        end
      end

      def node_ids_of(assignments)
        if assignments.is_a?(Sequel::Dataset)
          assignments.select_map(:node_id)
        else
          assignments.map(&:node_id)
        end
      end

      def child_node_ids_of(parent_node_ids)
        AccessControl.ac_parents.filter(:parent_id => parent_node_ids).
          select_map(:child_id)
      end

      def propagate_descendants(source_ids, params)
        child_node_ids    = params[:to]
        child_nodes_scope = params[:scoped_by]

        descend(source_ids, :scoped_by => child_nodes_scope)
        new_ids = propagated_ids_from(source_ids, :at => child_node_ids)

        # Next levels are propagated always without scope.
        next_child_node_ids = child_node_ids_of(child_node_ids)
        if next_child_node_ids.any?
          propagate_descendants(new_ids, :to => next_child_node_ids)
        end
      end

      def descend(source_ids, params)
        child_nodes_scope = params[:scoped_by]
        combos = combinations_of(source_ids, :scoped_by => child_nodes_scope)

        import([:parent_id, :role_id, :principal_id, :node_id], combos)
      end

      def combinations_of(source_ids, params)
        filter_params = { :ac_assignments__id => source_ids }

        child_nodes_scope = params[:scoped_by]
        if child_nodes_scope
          filter_params[:ac_parents__child_id] = child_nodes_scope
        end

        select(:ac_assignments__id, :role_id, :principal_id,
               :ac_parents__child_id).
          join_table(:inner, :ac_parents,
                     :ac_assignments__node_id => :ac_parents__parent_id).
          filter(filter_params)
      end

      def propagated_ids_from(parent_ids, params)
        child_node_ids = params[:at]
        filter(:node_id => child_node_ids,
               :parent_id => parent_ids).select_map(:id)
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
