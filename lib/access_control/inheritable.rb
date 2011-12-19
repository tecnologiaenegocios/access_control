require 'access_control/exceptions'
require 'access_control/orm'

module AccessControl
  class Inheritable

    attr_reader :orm

    def initialize(orm)
      raise InvalidInheritage unless Inheritance.recognizes?(orm.object)
      @orm = orm
    end

    def ids_with(permissions)
      Util.compact_flat_set(parent_models_and_ids) do |association|
        query_ids(association, permissions)
      end
    end

  private

    def parent_models_and_ids
      orm.object.inherits_permissions_from.map do |assoc|
        OpenStruct.new(
          :model => orm.associated_class(assoc),
          :name  => assoc,
          :ids   => orm.foreign_keys(assoc)
        )
      end
    end

    def query_ids(association, permissions)
      restricter = Restricter.new(association.model)
      condition  = restricter.sql_condition(permissions, association.ids)

      if condition == '0'
        Set.new
      else
        Set.new orm.primary_keys(condition, association.name)
      end
    end

  end
end
