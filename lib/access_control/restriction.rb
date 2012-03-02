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
          wrap_with_permissions_for_result_set { super }
        else
          permissions = permissions_required_to_show
          manager = AccessControl.manager
          results = super(*args)
          test_results = Array(results)
          test_results.each { |result| manager.can!(permissions, result) }
          results
        end
      end

      def calculate(*args)
        return super unless AccessControl.manager.restrict_queries?
        wrap_with_permissions_for_result_set { super }
      end

      def unrestricted_find(*args)
        AccessControl.manager.without_query_restriction { find(*args) }
      end

    private

      def wrap_with_permissions_for_result_set
        restricter = Restricter.new(ORM.adapt_class(self))
        subquery = restricter.sql_query_for(permissions_required_to_list)
        condition = "#{quoted_table_name}.#{primary_key} IN (#{subquery})"
        with_scope(:find => { :conditions => condition }) { yield }
      end
    end
  end
end
