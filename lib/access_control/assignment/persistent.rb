require 'access_control/assignment'
require 'access_control/ids'

module AccessControl
  class Assignment::Persistent < ActiveRecord::Base
    set_table_name :ac_assignments

    extend AccessControl::Ids

    def self.with_nodes(nodes)
      node_ids = Util.ids_for_hash_condition(nodes)
      subquery = Node::Persistent.column_sql(:id, node_ids)
      scoped(:conditions => "#{quoted_table_name}.node_id IN (#{subquery})")
    end

    def self.with_roles(roles)
      role_ids = Util.ids_for_hash_condition(roles)
      subquery = Role::Persistent.column_sql(:id, role_ids)
      scoped(:conditions => "#{quoted_table_name}.role_id IN (#{subquery})")
    end

    def self.assigned_to(principals)
      principal_ids = Util.ids_for_hash_condition(principals)
      subquery = Principal::Persistent.column_sql(:id, principal_ids)
      scoped(:conditions => "#{quoted_table_name}.principal_id IN (#{subquery})")
    end

    def self.assigned_on(nodes, principals)
      with_nodes(nodes).assigned_to(principals)
    end

    def self.overlapping(roles_ids, principals_ids, nodes_ids)
      with_roles(roles_ids).
        assigned_to(principals_ids).
        with_nodes(nodes_ids)
    end
  end
end
