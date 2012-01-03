module AccessControl
  module Ids

    def ids
      select_values_of_column(:id)
    end

    def with_ids(ids)
      scoped(:conditions => { :id => ids })
    end

    def select_values_of_column(column_name)
      sql = column_sql(column_name)
      connection.select_values(sql)
    end

    def scoped_column(column_name)
      scoped(:select => "DISTINCT #{quoted_table_name}.#{column_name}")
    end

    def column_sql(column_name)
      scoped_column(column_name).sql
    end

  end
end

# This feature is needed but is not available in Rails 2.3.x.
unless ActiveRecord::NamedScope::Scope.method_defined?('sql')
  module ActiveRecord
    module NamedScope
      class Scope
        def sql
          construct_finder_sql({})
        end
      end
    end
  end
end
