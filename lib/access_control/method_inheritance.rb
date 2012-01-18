require 'access_control/db'
require 'access_control/node'

module AccessControl
  class MethodInheritance

    attr_reader :model_class, :method_name
    def initialize(model_class, method_name)
      @model_class = model_class
      @method_name = method_name
    end

    def relationships(records = model_class.all)
      records.each_with_object(Array.new) do |record, results|
        parent_record = record.send(method_name)

        node_id        = nodes[record] && nodes[record].id
        parent_node_id = nodes[parent_record] && nodes[parent_record].id

        next unless node_id && parent_node_id

        [parent_node_id, node_id].tap do |relationship|
          yield relationship if block_given?
          results << relationship
        end
      end
    end

    alias_method :relationships_of, :relationships

    def ==(other)
      if other.class == self.class
        other.properties == properties
      else
        false
      end
    end
    alias_method :eql?, :==

    def properties
      {:model_class => model_class, :method_name => method_name}
    end

  private

    def nodes
      @nodes ||= Hash.new do |hash, record|
        hash[record] = AccessControl::Node(record) unless record.nil?
      end
    end

  end
end
