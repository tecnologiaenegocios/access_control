require 'forwardable'

module AccessControl
  module Persistable
    class WrappedSubset
      include Enumerable
      extend Forwardable

      def initialize(persistable_model, original_subset)
        @persistable_model = persistable_model
        @original_subset   = original_subset
      end

      def_delegators :original_subset, :count, :any?, :empty?, :sql

      def each
        return to_enum(:each) unless block_given?

        original_subset.each do |item|
          wrap(item).tap { |wrapped| yield wrapped }
        end
      end

      def all
        @wrapped_items ||= each.to_a
      end

      def scoped_column(column_name)
        # Warning: this method has the assumption that the original scope is an
        # ActiveRecord's one.
        new_scope = original_subset.scoped_column(column_name)
        self.class.new(persistable_model, new_scope)
      end

      def inspect
        hex_object_id = sprintf '0x%x', 2 * object_id
        "#<#{self.class.name}:#{hex_object_id}>"
      end

      def method_missing(method_name, *args, &block)
        if original_subset.respond_to?(method_name)
          new_original_subset =
            original_subset.public_send(method_name, *args, &block)
          self.class.new(persistable_model, new_original_subset)
        else
          super
        end
      end

    private
      attr_reader :original_subset, :persistable_model

      def wrap(item)
        persistable_model.wrap(item)
      end
    end
  end
end
