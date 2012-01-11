module AccessControl
  module DatasetHelper
    def self.included(base)
      base.extend(ClassMethods)
    end

    def self.use_subqueries?
      @use_subqueries ||= (RAILS_ENV != 'test')
    end

    def self.use_subqueries= value
      @use_subqueries = value
    end

    module ClassMethods
      def column_dataset(column, values)
        if DatasetHelper.use_subqueries? && values && !values.is_a?(Fixnum)
          filter(column => values).select(column)
        else
          values
        end
      end
    end
  end
end
