require 'access_control/blockable'
require 'access_control/exceptions'
require 'access_control/grantable'
require 'access_control/inheritable'
require 'access_control/orm'

module AccessControl

  class Restricter

    attr_reader :model

    def initialize(model)
      @model = model
    end

    def permitted_ids(permissions, filter=nil)
      granted_ids = grantable.ids_with(permissions)
      inherited_ids = Inheritable.new(model).ids_with(permissions)
      ids = (inherited_ids - blocked_ids) | granted_ids
      ids = (Set.new(filter) & ids) if filter
      ids
    end

    def sql_condition(permissions, filter=nil)
      return '1' if manager.can?(permissions, global_node)
      if grantable.from_class?(permissions)
        if blocked_ids.any?
          ids = blocked_ids - grantable.ids_with(permissions)
          ids.any? ? "#{table_id} NOT IN (#{quote(ids)})" : '1'
        else
          filter ? "#{table_id} IN (#{quote(filter)})" : '1'
        end
      else
        ids = permitted_ids(permissions, filter)
        if ids.any?
          "#{table_id} IN (#{quote(ids)})"
        else
          '0'
        end
      end
    end

  private

    def grantable
      @grantable ||= Grantable.new(model)
    end

    def blocked_ids
      @blocked_ids ||= Blockable.new(model).ids
    end

    def manager
      AccessControl.manager
    end

    def global_node
      AccessControl.global_node
    end

    def table_id
      @table_id ||= model.full_pk
    end

    def quote(values)
      model.quote_values(values.to_a)
    end

  end

end
