require 'access_control/db'
require 'access_control/node'

module AccessControl
  class AssociationInheritance

    attr_reader :model_class, :key_name, :parent_type, :association_name
    def initialize(model_class, key_name, parent_type, association_name)
      @model_class      = model_class
      @orm              = ORM.adapt_class(model_class)
      @key_name         = key_name.to_sym
      @parent_type      = parent_type
      @association_name = association_name.to_sym
    end

    def relationships(collection = record_table, &block)
      if collection.kind_of?(Sequel::Dataset)
        relationships = relationships_for_dataset(collection)
      elsif collection.kind_of?(Enumerable)
        relationships = relationships_for_collection(collection)
      else
        raise ArgumentError, "Incompatible collection type #{collection.class}"
      end

      relationships.each(&block) if block
      relationships
    end
    alias_method :relationships_of, :relationships

    def parent_nodes_of(securable)
      result = [associated_record(securable)]
      result.compact.map { |record| AccessControl::Node(record) }
    end

    def relationships_for_collection(collection)
      tuples = collection.map do |item|
        [item.public_send(key_name), pk_of(item)]
      end

      AccessControl.db.
        from(:ac_nodes, :ac_nodes => :parent_nodes).
        filter(:securable_type.qualify(:parent_nodes) => parent_type,
               :securable_type.qualify(:ac_nodes)     => record_type).
        filter([ :securable_id.qualify(:parent_nodes),
                 :securable_id.qualify(:ac_nodes) ]   => tuples).
        select(:id.qualify(:parent_nodes) => :parent_id,
               :id.qualify(:ac_nodes)     => :child_id)
    end
    private :relationships_for_collection

    def relationships_for_dataset(dataset)
      child_nodes_clause = join_clause("child_nodes", record_type,
                                       :id.qualify(record_table_name))

      parent_nodes_clause = join_clause("parent_nodes", parent_type,
                                        key_name.qualify(record_table_name))

      dataset.inner_join(*child_nodes_clause).
              inner_join(*parent_nodes_clause).
              select(:parent_nodes__id => :parent_id,
                     :child_nodes__id  => :child_id)
    end
    private :relationships_for_dataset

    def ==(other)
      if other.class == self.class
        other.properties == properties
      else
        false
      end
    end
    alias_method :equal?, :==

    def properties
      { :record_type => record_type,
        :key_name    => key_name,
        :parent_type => parent_type }
    end

  private

    def record_type
      model_class.name
    end

    def record_table_name
      @orm.table_name
    end

    def join_clause(nodes_alias, securable_type, id_spec)
      [:ac_nodes,
       { :securable_type.qualify(nodes_alias) => securable_type,
         :securable_id.qualify(nodes_alias)   => id_spec },
       { :table_alias => nodes_alias } ]
    end

    def record_table
      @record_table ||= AccessControl.db[record_table_name]
    end

    def pk_of(securable)
      securable.public_send(@orm.pk_name)
    end

    def associated_record(securable)
      AccessControl.manager.without_query_restriction do
        securable.send(association_name)
      end
    end
  end
end
