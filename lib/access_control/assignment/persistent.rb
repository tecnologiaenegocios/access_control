require 'access_control/assignment'
require 'access_control/ids'
require 'sequel/plugins/tree'

module AccessControl
  class Assignment::Persistent < Sequel::Model(:ac_assignments)
    plugin :tree, :key => :parent_id

    self.raise_on_save_failure = true

    def_dataset_method :with_nodes do |nodes|
      node_ids = Util.ids_for_hash_condition(nodes)
      # Remember that Node still is AR::Base backed.
      subquery = Node::Persistent.column_sql(:id, node_ids)
      filter(:node_id => AccessControl.db[subquery])
    end

    def_dataset_method :with_roles do |roles|
      role_ids = Util.ids_for_hash_condition(roles)
      filter :role_id => Role::Persistent.column_dataset(:id, role_ids)
    end

    def_dataset_method :assigned_to do |principals|
      principal_ids = Util.ids_for_hash_condition(principals)
      # Remember that Principal still is AR::Base backed.
      subquery = Principal::Persistent.column_sql(:id, principal_ids)
      filter(:principal_id => AccessControl.db[subquery])
    end

    def_dataset_method :assigned_on do |nodes, principals|
      with_nodes(nodes).assigned_to(principals)
    end

    def_dataset_method :overlapping do |roles_ids, principals_ids, nodes_ids|
      with_roles(roles_ids).assigned_on(nodes_ids, principals_ids)
    end

    def_dataset_method :children_of do |assignment|
      assignment_id = Util.ids_for_hash_condition(assignment)
      filter(:parent_id => assignment_id)
    end

    subset(:real,       {:parent_id => nil})
    subset(:effective, ~{:parent_id => nil})
  end
end
