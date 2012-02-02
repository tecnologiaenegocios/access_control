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
          subquery = Restricter.new(adapted).sql_query_for(permissions)
          condition = "#{quoted_table_name}.#{primary_key} IN (#{subquery})"
          with_scope(:find => { :conditions => condition }) { super }
        else
          permission_names = permissions_required_to_show
          permissions      = AccessControl::Registry.fetch_all(permission_names)
          manager = AccessControl.manager
          results = super(*args)
          test_results = Array(results)
          test_results.each { |result| manager.can!(permissions, result) }
          results
        end
      end

      def unrestricted_find(*args)
        AccessControl.manager.without_query_restriction { find(*args) }
      end

    end

  end
end
