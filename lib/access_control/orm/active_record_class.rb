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

      def sti_subquery
        find_options = { :select => pk_name }
        if is_base_class_in_sti?
          column = "`#{table_name}`.`#{sti_column}`"
          find_options[:conditions] =
            "#{column} = #{quote(name)} OR #{column} IS NULL"
        end
        object.scoped(find_options).send(:construct_finder_sql, {})
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

    private

      def is_base_class_in_sti?
        child_of_active_record_base? && has_sti?
      end

      def child_of_active_record_base?
        object.superclass == ActiveRecord::Base
      end

      def has_sti?
        column_names.include?(sti_column)
      end

      def sti_column
        column = object.inheritance_column
        column.to_sym if column.present?
      end

      def quote(value)
        object.connection.quote(value)
      end
    end
  end
end
