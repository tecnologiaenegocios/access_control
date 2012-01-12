require 'access_control/assignment'
require 'access_control/ids'
require 'sequel/plugins/tree'

module AccessControl
  class Assignment::Persistent < Sequel::Model(:ac_assignments)
    plugin :tree, :key => :parent_id

    self.raise_on_save_failure = true

    def self.propagate_all(assignments, overrides = {})
      if assignments.kind_of?(Sequel::Dataset)
        columns_to_propagate = [:role_id, :principal_id, :node_id] | overrides.keys

        columns_to_select = columns_to_propagate.map do |column_name|
          if overrides.has_key?(column_name)
            {overrides[column_name] => column_name}
          else
            column_name
          end
        end

        dataset = assignments.select(*columns_to_select)

        import(columns_to_propagate+[:parent_id], dataset.select_append(:id))
      else
        definitions = assignments.map do |assignment|
          properties = assignment.values
          properties[:parent_id] = properties.delete(:id)
          properties.merge(overrides)
        end
        multi_insert(definitions)
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
