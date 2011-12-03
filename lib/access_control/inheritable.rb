require 'access_control/exceptions'
require 'access_control/orm'

module AccessControl
  class Inheritable

    attr_reader :orm

    def initialize(orm)
      raise InvalidInheritage unless orm.object.include?(Inheritance)
      @orm = orm
    end

    def ids_with(permissions)
      parent_models_and_ids.inject(Set.new) do |ids, (other, assoc, filter)|
        ids | query_ids(assoc, other, permissions, filter)
      end
    end

  private

    def parent_models_and_ids
      orm.object.inherits_permissions_from.inject([]) do |items, assoc|
        items << [
          orm.associated_class(assoc),
          assoc,
          orm.foreign_keys(assoc)
        ]
      end
    end

    def query_ids(association, reflected_orm, permissions, filter)
      condition = Restricter.new(reflected_orm).
        sql_condition(permissions, filter)
      return Set.new if condition == '0'
      Set.new(orm.primary_keys(condition, association))
    end

  end
end
