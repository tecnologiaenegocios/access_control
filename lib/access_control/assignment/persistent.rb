require 'access_control/assignment'
require 'access_control/ids'
require 'sequel/plugins/tree'

module AccessControl
  class Assignment::Persistent < Sequel::Model(:ac_assignments)
    self.raise_on_save_failure = true

    class << self
      def propagate_to(assignments, node_id)
        node_and_descendants_in_order(ids_of(assignments), node_id) \
            do |ids, child_node_ids|
          copy_from_ids_to_nodes_and_return_ids_by_level(ids, child_node_ids)
        end
      end

      def propagate_to_descendants(assignments, node_id)
        descendants_in_order({node_id => ids_of(assignments)},
                             node_id) do |ids, child_node_ids|
          copy_from_ids_to_nodes_and_return_ids_by_level(ids, child_node_ids)
        end
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

      def node_and_descendants_in_order(parent_ids, node_id, &block)
        ids_by_level = block.call(parent_ids, node_id)
        descendants_in_order(ids_by_level, node_id, &block)
      end

      def descendants_in_order(ids_by_level, node_id)
        im = Node::InheritanceManager.new(node_id)
        im.descendant_ids do |parent_node_id, child_node_ids|
          new_ids = yield(ids_by_level[parent_node_id], child_node_ids)
          new_ids.each do |node_id, ids|
            ids_by_level[node_id] ||= []
            ids_by_level[node_id].concat(ids).uniq!
          end
        end
      end

      def ids_of(assignments)
        if assignments.is_a?(Sequel::Dataset)
          assignments.select_map(:id)
        else
          assignments.map(&:id)
        end
      end

      def copy_from_ids_to_nodes_and_return_ids_by_level(parent_ids, node_ids)
        copy_from_ids_to_nodes(parent_ids, node_ids)
        ids_with_parents_by_nodes(parent_ids, node_ids)
      end

      def copy_from_ids_to_nodes(parent_ids, node_ids)
        import([:parent_id, :role_id, :principal_id, :node_id],
               combinations_as_dataset(parent_ids, node_ids))
      end

      def combinations_as_dataset(parent_ids, node_ids)
        select(:ac_assignments__id, :role_id, :principal_id, :ac_nodes__id).
        from(:ac_assignments, :ac_nodes).
        filter(:ac_assignments__id => parent_ids, :ac_nodes__id => node_ids)
      end

      def ids_with_parents_by_nodes(parent_ids, node_ids)
        tuples = filter(:node_id => node_ids, :parent_id => parent_ids).
          select_map([:id, :node_id])
        tuples.each_with_object({}) do |(id, node_id), groups|
          groups[node_id] ||= []
          groups[node_id] << id
        end
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
