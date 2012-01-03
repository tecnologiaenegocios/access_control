require 'access_control/assignment'
require 'access_control/ids'

module AccessControl
  class Assignment::Persistent < ActiveRecord::Base
    set_table_name :ac_assignments

    extend AccessControl::Ids

    def self.with_nodes(nodes)
      node_id = Util.ids_for_hash_condition(nodes)
      scoped(:conditions => { :node_id => node_id })
    end

    def self.with_roles(roles)
      roles = Util.ids_for_hash_condition(roles)
      scoped(:conditions => { :role_id => roles })
    end

    def self.assigned_to(principal)
      principal = Util.ids_for_hash_condition(principal)
      scoped(:conditions => { :principal_id => principal })
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
