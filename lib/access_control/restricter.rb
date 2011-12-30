require 'access_control/orm'

module AccessControl
  class Restricter
    def initialize(orm_class)
      @orm_class = orm_class
    end

    def sql_query_for(permissions)
      if manager.can?(permissions, global_node)
        "SELECT #{orm_class.pk} FROM #{orm_class.quoted_table_name}"
      else
        "SELECT node_id FROM `ac_effective_assignments` "\
          "WHERE role_id IN (#{sql_role_ids(permissions)}) AND "\
          "principal_id IN (#{sql_principal_ids})"
      end
    end

  private

    def orm_class
      @orm_class
    end

    def manager
      AccessControl.manager
    end

    def global_node
      AccessControl.global_node
    end

    def sql_role_ids(permissions)
      sql_ids(Role.for_all_permissions(permissions))
    end

    def sql_principal_ids
      sql_ids(manager.principals)
    end

    def sql_ids(collection)
      collection.map(&:id).map(&:to_s).join(',')
    end
  end
end
