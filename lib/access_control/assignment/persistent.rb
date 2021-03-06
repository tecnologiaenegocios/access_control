require 'access_control/assignment'
require 'access_control/ids'
require 'sequel/plugins/tree'

module AccessControl
  class Assignment::Persistent < Sequel::Model(:ac_assignments)
    self.raise_on_save_failure = true

    dataset_module do
      def with_nodes(nodes)
        node_ids = Util.ids_for_hash_condition(nodes)
        filter :node_id => Node::Persistent.column_dataset(:id, node_ids)
      end

      def with_roles(roles)
        role_ids = Util.ids_for_hash_condition(roles)
        filter :role_id => Role::Persistent.column_dataset(:id, role_ids)
      end

      def assigned_to(principals)
        principal_ids = Util.ids_for_hash_condition(principals)
        dataset = Principal::Persistent.column_dataset(:id, principal_ids)
        filter :principal_id => dataset
      end

      def assigned_on(nodes, principals)
        with_nodes(nodes).assigned_to(principals)
      end

      def overlapping(roles_ids, principals_ids, nodes_ids)
        with_roles(roles_ids).assigned_on(nodes_ids, principals_ids)
      end
    end
  end
end
