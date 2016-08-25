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

      ancestor_ids = granting_node_ids(permissions)
      return orm_class.none_sql if ancestor_ids.empty?

      db[:ac_nodes]
        .filter(id: reachable_node_ids(ancestor_ids))
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

    def reachable_node_ids(ancestor_ids)
      NodeGraph.new { |result| result }.reachable_from(ancestor_ids)
    end

    def granting_node_ids(permissions)
      db[:ac_assignments]
        .filter(role_id: role_ids(permissions))
        .filter(principal_id: principal_ids)
        .filter(node_id: non_leaf_or_from_securable_class.select(:id))
        .select_map { distinct(node_id) }
    end

    def non_leaf_or_from_securable_class
      securable_class = orm_class.name
      non_leaf_node_ids = db[:ac_parents].select(:parent_id)

      db[:ac_nodes].filter do
        (securable_type =~ securable_class) | (id =~ non_leaf_node_ids)
      end
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
