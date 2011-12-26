module AccessControl
  module Persistable
    class WrapperScope
      include Enumerable

      def initialize(persistable_model, original_scope)
        @persistable_model = persistable_model
        @original_scope    = original_scope
      end

      delegate :count, :any?, :empty?, :to => :original_scope

      def each
        all.each { |item| yield(item) if block_given? }
      end

      def all
        @wrapped_items ||= original_scope.map { |item| wrap(item) }
      end

      def inspect
        hex_object_id = sprintf '0x%x', 2 * object_id
        "#<#{self.class.name}:#{hex_object_id}>"
      end

    private

      def wrap(item)
        persistable_model.wrap(item)
      end

      attr_reader :original_scope, :persistable_model
    end
  end
end
