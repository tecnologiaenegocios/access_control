require 'access_control/db'
require 'access_control/node'

module AccessControl
  class AssociationInheritance

    attr_reader :model_class, :key_name, :parent_type
    def initialize(model_class, key_name, parent_type)
      @model_class = model_class
      @key_name    = key_name.to_sym
      @parent_type = parent_type
    end

    def relationships(collection = record_table, &block)
      dataset = normalize_to_dataset(collection)

      child_nodes_clause = join_clause("child_nodes", record_type,
                                       :id.qualify(record_table_name))

      parent_nodes_clause = join_clause("parent_nodes", parent_type,
                                        key_name.qualify(record_table_name))

      relationships = dataset.inner_join(*child_nodes_clause).
                              inner_join(*parent_nodes_clause).
                              select(:parent_nodes__id => :parent_id,
                                     :child_nodes__id  => :child_id)
      if block
        relationships.each(&block)
      end
      relationships
    end
    alias_method :relationships_of, :relationships

    def ==(other)
      if other.class == self.class
        other.properties == properties
      else
        false
      end
    end
    alias_method :equal?, :==

    def properties
      { :model_class => model_class,
        :key_name    => key_name,
        :parent_type => parent_type }
    end

  private

    def record_type
      model_class.name
    end

    def record_table_name
      model_class.table_name.to_sym
    end

    def join_clause(nodes_alias, securable_type, id_spec)
      [:ac_nodes,
       { :securable_type.qualify(nodes_alias) => securable_type,
         :securable_id.qualify(nodes_alias)   => id_spec },
       { :table_alias => nodes_alias } ]
    end

    def normalize_to_dataset(object)
      if object.kind_of?(Sequel::Dataset)
        object
      elsif object.kind_of?(Enumerable)
        record_table.filter(:id.qualify(record_table_name) => object.map(&:id))
      else
        raise ArgumentError, "Incompatible collection type #{object.class}"
      end
    end

    def record_table
      @reciord_table ||= AccessControl.db[record_table_name]
    end
  end
end
