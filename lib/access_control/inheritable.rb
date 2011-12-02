require 'access_control/exceptions'
require 'access_control/orm'

module AccessControl
  class Inheritable

    attr_reader :model

    def initialize(model)
      raise InvalidInheritage unless model.object.include?(Inheritance)
      @model = model
    end

    def ids_with(permissions)
      parent_models_and_ids.inject(Set.new) do |ids, (other, assoc, filter)|
        ids | query_ids(assoc, other, permissions, filter)
      end
    end

  private

    def parent_models_and_ids
      model.object.inherits_permissions_from.inject([]) do |items, assoc|
        items << [
          model.associated_class(assoc),
          assoc,
          model.foreign_keys(assoc)
        ]
      end
    end

    def query_ids(association, reflected_model, permissions, filter)
      condition = Restricter.new(reflected_model).
        sql_condition(permissions, filter)
      return Set.new if condition == '0'
      Set.new(model.primary_keys(condition))
    end

  end
end
