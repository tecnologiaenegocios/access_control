module AccessControl
  class Node::WrapperScope

    include Enumerable

    def initialize(original_scope)
      @original_scope = original_scope
    end

    delegate :count, :any?, :empty?, :to => :original_scope

    def each(&block)
      all.each(&block)
    end

    def all
      @wrapped_nodes ||= original_scope.map { |item| Node.wrap(item) }
    end

    def inspect
      hex_object_id = sprintf '0x%x', self.object_id
      "#<#{self.class.name}:#{hex_object_id}>"
    end

  private
    attr_reader :original_scope

  end
end
