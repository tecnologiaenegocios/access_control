module AccessControl
  module ORM

    class Base
      def full_pk
        "#{quoted_table_name}.#{pk}"
      end
    end

    class << self
      def adapt_class(object)
        # We only support ActiveRecord::Base by now.
        ActiveRecordClass.new(object)
      end
    end

    class ActiveRecordClass < Base

      attr_reader :object

      def initialize(object)
        @object = object
      end

      # The name of the class, as a string.
      def name
        object.name
      end

      # The primary key name, as string.
      def pk
        object.primary_key
      end

      # The quoted table name, as string.
      def quoted_table_name
        object.quoted_table_name
      end

      # Given an array of values, return it as a string suitable for a IN or
      # NOT IN SQL condition.
      def quote_values(values)
        return connection.quote(nil) if values.empty?
        values.map { |i| connection.quote(i) }.join(',')
      end

      # Given a string or symbol naming an association, get the ORM from the
      # class corresponding to that symbol.
      def associated_class(sym)
        ORM.adapt_class(object.reflections[sym.to_sym].klass)
      end

      # Get all of the ORM class table's primary keys which are in the given
      # SQL fragment used as condition (for the WHERE clause).
      #
      # A join association, if given, should be used in the SQL (it may provide
      # some joins for the conditions).
      #
      # The resulting array must not be filtered by AccessControl, thus .find
      # should not be used (or should only be used inside a
      # AccessControl.manager.without_query_restriction block).
      def primary_keys(sql_condition, join_association=nil)
        connection.select_values(scoped(
          :select     => full_pk,
          :conditions => sql_condition,
          :joins      => join_association
        ).sql)
      end

      # Given a join association, get all of its primary keys which are related
      # with this ORM class.
      #
      # The resulting array must not be filtered by AccessControl, thus .find
      # should not be used (or should only be used inside a
      # AccessControl.manager.without_query_restriction block).
      def foreign_keys(join_association)
        reflected = associated_class(join_association)
        connection.select_values(scoped(
          :select => reflected.full_pk,
          :joins  => join_association
        ).sql)
      end

    private

      def connection
        object.connection
      end

      def scoped(*args)
        object.scoped(*args)
      end
    end
  end
end
