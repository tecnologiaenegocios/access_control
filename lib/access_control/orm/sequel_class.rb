require 'access_control/orm'
require 'backports'

module AccessControl
  module ORM
    class SequelClass < Base
      def initialize(object)
        @object = object
      end

      def table_name
        object.table_name.to_sym
      end

      def pk_name
        object.primary_key.to_sym
      end

      def column_names
        object.columns
      end

      def [](pk)
        object[pk]
      end

      def values_at(*pks)
        object.filter(pk_name => pks).all
      end

      def include?(pk)
        !object.filter(pk_name => pk).empty?
      end

      def size
        object.count
      end

      def values
        to_enum(:values_as_enum)
      end

      def subset(name, *args)
        object.public_send(name, *args)
      end

      def instance_eql?(instance, other)
        instance == other
      end

      def persist(instance)
        instance.save
      end

      def persisted?(instance)
        !instance.new?
      end

      def delete(instance)
        instance.destroy
      end

    private

      def values_as_enum(&block)
        object.each_page(AccessControl.default_batch_size) do |page|
          page.each(&block)
        end
      end
    end
  end
end
