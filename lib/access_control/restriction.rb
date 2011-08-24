require 'access_control/restricter'

module AccessControl
  module Restriction

    def self.included(base)
      base.extend(ClassMethods)
    end

    def valid?
      AccessControl.security_manager.without_query_restriction do
        super
      end
    end

    module ClassMethods

      def find(*args)
        unless AccessControl.security_manager.restrict_queries?
          return super(*args)
        end
        case args.first
        when :all, :last, :first
          permissions = permissions_required_to_query
          with_scope(:find => Restricter.new(self).options(permissions)) do
            super(*args)
          end
        else
          permissions = permissions_required_to_view
          results = super(*args)
          test_results = results
          test_results = [results] if !test_results.is_a?(Array)
          test_results.each do |result|
            AccessControl.security_manager.verify_access!(result, permissions)
          end
          results
        end
      end

      def unrestricted_find(*args)
        AccessControl.security_manager.without_query_restriction do
          find(*args)
        end
      end

    end

  end
end
