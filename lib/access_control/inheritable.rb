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
        ids | Set.new(model.unrestricted_find(:all, { :joins => assoc }.merge(
          Restricter.new(other).options(permissions, filter)
        )).map(&(model.primary_key.to_sym.to_proc)))
      end
    end

  private

    def parent_models_and_options
      model.parent_models_and_options
    end

  end
end
