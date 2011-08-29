require 'access_control/security_manager'

module AccessControl
  module AssociationSecurity
    def self.included(base)
      base.class_eval do
        alias_method :restricted_find_target, :find_target
        alias_method :find_target, :unrestricted_find_target
        private :find_target
      end
    end
    def unrestricted_find_target
      return restricted_find_target unless \
        @reflection.active_record.respond_to?(:association_restricted?)
      return restricted_find_target if @reflection.active_record.
        association_restricted?(@reflection.name.to_sym)
      AccessControl.security_manager.without_query_restriction do
        restricted_find_target
      end
    end
  end
end

ActiveRecord::Associations::BelongsToAssociation.class_eval do
  include AccessControl::AssociationSecurity
end

ActiveRecord::Associations::BelongsToPolymorphicAssociation.class_eval do
  include AccessControl::AssociationSecurity
end
