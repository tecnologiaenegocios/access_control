require 'access_control/orm'
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
          permissions = permissions_required_to_index
          adapted = ORM.adapt_class(self)
          joins = Restricter.new(adapted).sql_join_expression(permissions)
          with_scope(:find => { :joins => joins }) { super }
        else
          permissions = permissions_required_to_show
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
