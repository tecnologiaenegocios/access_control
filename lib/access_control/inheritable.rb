require 'access_control/exceptions'

module AccessControl
  class Inheritable

    attr_reader :model

    def initialize(model)
      raise InvalidInheritage unless model.include?(Inheritance)
      raise CannotRestrict unless model.include?(Restriction)
      @model = model
    end

    def ids_with(permissions)
      parent_models_and_options.inject(Set.new) do |ids, (other, assoc, filter)|
        ids | query_ids(assoc, other, permissions, filter)
      end
    end

  private

    def parent_models_and_options
      model.parent_models_and_options
    end

    def query_ids(association, reflected_model, permissions, filter)
      condition = Restricter.new(reflected_model).
        sql_condition(permissions, filter)
      return Set.new if condition == '0'
      Set.new(model.unrestricted_find(
        :all,
        :select => "#{model.quoted_table_name}.#{model.primary_key}",
        :joins => association,
        :conditions => condition
      )).map(&(model.primary_key.to_sym))
    end

  end
end
