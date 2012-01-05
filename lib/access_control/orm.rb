module AccessControl
  module ORM
    class Base
      attr_reader :object
      # The name of the class, as a symbol.
      def name
        object.name.to_sym
      end

      # Forwards the instantiation of the underlying object.
      #
      # For all purposes, instantiating the adapted class or the underlying
      # class object itself returns an object with the same interface.  The
      # simplest way to achieve this is by delegating instantiation and using
      # instances directly from the underlying ORM.
      def new
        object.new
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

      def pk_name
        object.primary_key.to_sym
      end

      def table_name
        object.table_name.to_sym
      end

      def column_names
        object.column_names.map(&:to_sym)
      end

      def [] pk
        object.send(:"find_by_#{pk_name}", pk)
      end

      def values_at *pks
        pks = Array[*pks]
        object.all(:conditions => { pk_name => pks })
      end

      def include?(pk)
        object.exists?(pk)
      end

      def size
        object.count
      end

      def values
        object.all
      end

      def new
        object.new
      end

      def subset(method, *args)
        object.send(method, *args)
      end

      def instance_eql?(instance, other)
        instance == other
      end

      def persist(instance)
        instance.save
      end

      def persisted?(instance)
        !instance.new_record?
      end

      def delete(instance)
        instance.destroy
      end
    end
  end
end
