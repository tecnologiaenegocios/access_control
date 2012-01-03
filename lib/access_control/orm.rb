module AccessControl
  module ORM

    class Base
      attr_reader :object
      # The name of the class, as a symbol.
      def name
        object.name.to_sym
      end
    end

    class << self
      def adapt_class(object)
        # We only support ActiveRecord::Base by now.
        ActiveRecordClass.new(object)
      end
    end

    class ActiveRecordClass < Base
      def initialize(object)
        @object = object
      end

      # The primary key name, as a symbol.
      def pk
        object.primary_key.to_sym
      end

      # The name of the table, as a symbol.
      def table_name
        object.table_name.to_sym
      end
    end
  end
end
