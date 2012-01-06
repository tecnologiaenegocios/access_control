module AccessControl
  module Ids

    def self.use_subqueries?
      @use_subqueries ||= RAILS_ENV != "test"
    end

    def self.use_subqueries=(value)
      @use_subqueries = value
    end

    def ids
      select_values_of_column(:id)
    end

    def with_ids(ids)
      scoped(:conditions => { :id => ids })
    end

    def select_values_of_column(column_name)
      sql = scoped_column(column_name).sql
      connection.select_values(sql)
    end

    def scoped_column(column_name, values = nil)
      scope = scoped(:select => "DISTINCT #{quoted_table_name}.#{column_name}")
      if values
        scope = scope.scoped(:conditions => { column_name => values })
      end
      scope
    end

    def column_sql(column_name, values = nil)
      if AccessControl::Ids.use_subqueries?
        scoped_column(column_name, values).sql
      else
        values ||= select_values_of_column(column_name)

        ids = values.kind_of?(Enumerable) ? values : [values]
        ids.any?? ids.join(",") : "NULL"
      end
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
