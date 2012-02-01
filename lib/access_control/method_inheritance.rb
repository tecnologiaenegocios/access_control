require 'access_control/db'
require 'access_control/node'

module AccessControl
  class MethodInheritance

    attr_reader :model_class, :method_name
    def initialize(model_class, method_name)
      @model_class = model_class
      @orm         = ORM.adapt_class(model_class)
      @method_name = method_name
    end

    def relationships(records = @orm.values)
      e = to_enum(:relationships_as_enum, records)
      if block_given?
        e.each { |relationship| yield relationship }
      else
        e
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
      {:record_type => record_type, :method_name => method_name}
    end

  private

    def relationships_as_enum(records, &block)
      records.each_slice(1000) do |partition|
        partition.each do |record|
          method_result = record.send(method_name)

          unless method_result.kind_of?(Enumerable)
            method_result = Array(method_result)
          end

          relationships = relationship_hashes(record, method_result)
          relationships.each(&block)
        end
      end
    end

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

    def record_type
      model_class.name
    end
  end
end
