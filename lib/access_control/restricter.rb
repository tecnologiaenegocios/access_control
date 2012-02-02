require 'access_control/orm'

module AccessControl
  class Restricter
    def initialize(orm_class)
      @orm_class = orm_class
    end

    def sql_query_for(permission_names)
      permissions = AccessControl::Registry.fetch_all(permission_names)

      if manager.can?(permissions, global_node)
        db[orm_class.table_name].select(orm_class.pk_name).sql
      else
        ac_nodes.
          select(:securable_id).
          join_table(:left, :ac_assignments, :node_id => :id).
          filter(:securable_type => orm_class.name,
                 :role_id        => role_ids(permissions),
                 :principal_id   => principal_ids).
          sql
      end
    end

  private

    def orm_class
      @orm_class
    end

    def db
      AccessControl.db
    end

    def ac_nodes
      AccessControl.ac_nodes
    end

    def manager
      AccessControl.manager
    end

    def global_node
      AccessControl.global_node
    end

    def role_ids(permissions)
      Role.for_all_permissions(permissions).map(&:id)
    end

    def principal_ids
      manager.principals.map(&:id)
    end
  end
end
