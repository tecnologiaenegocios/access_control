require 'access_control/db'
require 'access_control/node'

module AccessControl
  class MethodInheritance

    attr_reader :model_class, :method_name
    def initialize(model_class, method_name)
      @model_class = model_class
      @method_name = method_name
    end

    def relationships(records = model_class.all, &block)
      records.each_with_object(Array.new) do |record, results|
        method_result = record.send(method_name)

        unless method_result.kind_of?(Enumerable)
          method_result = Array(method_result)
        end

        relationships = relationship_hashes(record, method_result)
        relationships.each(&block) if block_given?

        results.concat(relationships)
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

    def relationship_hashes(record, parents)
      node_id = node_id_of(record)

      parents.each_with_object(Array.new) do |parent_record, result|
        parent_node_id = node_id_of(parent_record)

        if node_id && parent_node_id
          result << { :parent_id => parent_node_id, :child_id => node_id }
        end
      end
    end

    def node_id_of(record)
      if record
        AccessControl::Node(record).id
      end
    end

  end
end
