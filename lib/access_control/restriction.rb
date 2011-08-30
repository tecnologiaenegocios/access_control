require 'access_control/restricter'

module AccessControl
  module Restriction

    def self.included(base)
      base.extend(ClassMethods)
    end

    def valid?
      AccessControl.manager.without_query_restriction { super }
    end

    module ClassMethods

      def find(*args)
        return super unless AccessControl.manager.restrict_queries?
        case args.first
        when :all, :last, :first
          permissions = permissions_required_to_query
          return super if AccessControl.manager.can?(permissions, Node.global)
          with_scope(:find => {
            :conditions => Restricter.new(self).sql_condition(permissions)
          }) do
            super
          end
        else
          permissions = permissions_required_to_view
          results = super(*args)
          test_results = results
          test_results = [results] if !test_results.is_a?(Array)
          test_results.each do |result|
            AccessControl.manager.can!(permissions, result)
          end
          results
        end
      end

      def unrestricted_find(*args)
        AccessControl.manager.without_query_restriction { find(*args) }
      end

    end

  end
end
