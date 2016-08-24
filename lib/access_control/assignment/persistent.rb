require 'access_control/assignment'
require 'access_control/ids'
require 'sequel/plugins/tree'

module AccessControl
  class Assignment::Persistent < Sequel::Model(:ac_assignments)
    self.raise_on_save_failure = true

    def_dataset_method :at_nodes do |nodes|
      filter(node_id: Util.ids_for_hash_condition(nodes))
    end

    def_dataset_method :effectively_at_nodes do |nodes|
      node_ids = Util.ids_for_hash_condition(nodes)
      ancestry = NodeGraph.new { |result| result }

      filter do
        (node_id =~ node_ids) | (node_id =~ ancestry.reaching(node_ids))
      end
    end

    def_dataset_method :of_roles do |roles|
      filter(role_id: Util.ids_for_hash_condition(roles))
    end

    def_dataset_method :to_principals do |principals|
      filter(principal_id: Util.ids_for_hash_condition(principals))
    end

    def_dataset_method :assigned_on do |nodes, principals|
      at_nodes(nodes).to_principals(principals)
    end

    def_dataset_method :effectively_assigned_on do |nodes, principals|
      effectively_at_nodes(nodes).to_principals(principals)
    end

    def_dataset_method :overlapping do |roles_ids, principals_ids, nodes_ids|
      of_roles(roles_ids).assigned_on(nodes_ids, principals_ids)
    end
  end
end
