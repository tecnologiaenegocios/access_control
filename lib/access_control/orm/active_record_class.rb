require 'access_control/orm'

module AccessControl
  module ORM
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
        object.enum_for(:find_each,
                        :batch_size => AccessControl.default_batch_size)
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
