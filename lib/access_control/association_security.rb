module AccessControl
  module AssociationSecurity
    module BelongsTo
      private
        def unrestricted_find_target
          return restricted_find_target if @reflection.active_record.
            association_restricted?(@reflection.name.to_sym)
          AccessControl.security_manager.without_query_restriction do
            restricted_find_target
          end
        end
    end
    module BelongsToPolymorphic
      private
        def unrestricted_find_target
          return restricted_find_target if @reflection.active_record.
            association_restricted?(@reflection.name.to_sym)
          return restricted_find_target if association_class.nil?
          AccessControl.security_manager.without_query_restriction do
            restricted_find_target
          end
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
