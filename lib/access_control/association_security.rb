module AccessControl
  module AssociationSecurity
    module BelongsTo
      private
        def unrestricted_find_target
          @reflection.klass.send(:disable_query_restriction)
          result = restricted_find_target
          @reflection.klass.send(:re_enable_query_restriction)
          result
        end
    end
    module BelongsToPolymorphic
      private
        def unrestricted_find_target
          return restricted_find_target if association_class.nil?
          association_class.send(:disable_query_restriction)
          result = restricted_find_target
          association_class.send(:re_enable_query_restriction)
          result
        end
    end
  end
end

ActiveRecord::Associations::BelongsToAssociation.class_eval do
  include AccessControl::AssociationSecurity::BelongsTo
  alias_method :restricted_find_target, :find_target
  alias_method :find_target, :unrestricted_find_target
end

ActiveRecord::Associations::BelongsToPolymorphicAssociation.class_eval do
  include AccessControl::AssociationSecurity::BelongsToPolymorphic
  alias_method :restricted_find_target, :find_target
  alias_method :find_target, :unrestricted_find_target
end
