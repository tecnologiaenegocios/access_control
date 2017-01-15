require 'access_control/orm/base'

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

      def dataset(subclasses: false)
        return AccessControl.db[table_name].select(pk_name) if !has_sti?

        qualified_sti_column = Sequel.qualify(table_name, sti_column)

        if subclasses
          types = all_types.map(&:name)
        else
          types = name
        end

        filter = Sequel.expr(qualified_sti_column => types)

        if topmost_base_sti_class?
          filter = filter | Sequel.expr(qualified_sti_column => nil)
        end

        AccessControl.db[table_name].select(pk_name).where(filter)
      end

      def all_sql(subclasses: false)
        dataset(subclasses: subclasses).sql
      end

      def none_sql
        AccessControl.db[table_name].select(pk_name).where(1 => 0).sql
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

      def topmost_base_sti_class?
        cls = object
        superclasses_between_active_record_base = []
        while cls.superclass != ActiveRecord::Base
          superclasses_between_active_record_base << (cls = cls.superclass)
        end

        superclasses_between_active_record_base.all? { |s| s.abstract_class? }
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

      def all_types
        @all_types ||=
          ObjectSpace.each_object(object.singleton_class).select do |s|
            # Instance singleton classes must not be returned.  They are
            # exposed in Ruby 2.3+.  Ignore all singleton classes as well.
            !s.singleton_class?
          end
      end
    end
  end
end
