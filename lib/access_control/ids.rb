module AccessControl
  module Ids

    def ids
      select_values_of_column(:id)
    end

    def with_ids(ids)
      scoped(:conditions => { :id => ids })
    end

    def method_missing method_name, *args, &block
      if foreign_key = belongs_to_association_ids_or_nil(method_name)
        return select_values_of_column(foreign_key)
      end
      super
    end

  private

    def belongs_to_association_ids_or_nil(method_name)
      if method_name.to_s.ends_with?('_ids')
        if r = reflections[method_name.to_s.gsub(/_ids$/, '').to_sym]
          if r.belongs_to?
            return r.primary_key_name
          end
        end
      end
    end

    def select_values_of_column(column_name)
      connection.select_values(scoped(
        :select => "#{quoted_table_name}.#{column_name}"
      ).to_sql)
    end
  end
end

# This feature is needed but is not available in Rails 2.3.x.
unless ActiveRecord::NamedScope::Scope.method_defined?('to_sql')
  module ActiveRecord
    module NamedScope
      class Scope
        def to_sql
          construct_finder_sql({})
        end
      end
    end
  end
end
