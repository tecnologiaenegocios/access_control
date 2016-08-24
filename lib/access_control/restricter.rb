require 'access_control/orm'
require 'access_control/node_graph'

module AccessControl
  class Restricter
    def initialize(orm_class)
      @orm_class = orm_class
    end

    def sql_query_for(permissions, skip_global: false)
      if manager.can?(permissions, global_node)
        return skip_global ? nil : orm_class.all_sql
      end

      candidate_parent_node_ids = parent_node_ids(permissions)
      return orm_class.none_sql if candidate_parent_node_ids.empty?

      db[:ac_nodes]
        .filter(id: reachable_node_ids(candidate_parent_node_ids))
        .filter(securable_type: orm_class.name)
        .select(:securable_id)
        .sql
    end

  private

    def orm_class
      @orm_class
    end

    def db
      AccessControl.db
    end

    def global_node
      AccessControl.global_node
    end

    def reachable_node_ids(parent_node_ids)
      NodeGraph.new { |result| result }.reachable_from(parent_node_ids)
    end

    def parent_node_ids(permissions)
      db[:ac_assignments]
        .filter(role_id: role_ids(permissions))
        .filter(principal_id: principal_ids)
        .select_map(:node_id)
    end

    def role_ids(permissions)
      Role.for_all_permissions(permissions).map(&:id)
    end

    def principal_ids
      manager.principals.map(&:id)
    end

    def manager
      AccessControl.manager
    end
  end
end
