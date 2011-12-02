module AccessControl
  module ORM

    class << self
      def adapt_class(object)
        # We only support ActiveRecord::Base by now.
        ActiveRecordClass.new(object)
      end
    end

    class ActiveRecordClass

      attr_reader :object

      def initialize(object)
        @object = object
      end

      # The name of the class, as a string.
      def name
        object.name
      end

      # The fully qualified primary key.
      def full_pk
        "#{object.quoted_table_name}.#{object.primary_key}"
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
      # The resulting array must not be filtered by AccessControl, thus .find
      # should not be used (or should only be used inside a
      # AccessControl.manager.without_query_restriction block).
      def primary_keys(sql_condition)
        connection.select_values(scoped(
          :select => full_pk,
          :conditions => sql_condition
        ).to_sql)
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
        ).to_sql)
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
