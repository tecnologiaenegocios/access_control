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
        from(:ac_nodes, Sequel.as(:ac_nodes, :parent_nodes)).
        filter(Sequel.qualify(:parent_nodes, :securable_type) => parent_type,
               Sequel.qualify(:ac_nodes,     :securable_type) => record_type).
        filter([ Sequel.qualify(:parent_nodes, :securable_id),
                 Sequel.qualify(:ac_nodes,     :securable_id) ] => tuples).
        select(Sequel.as(Sequel.qualify(:parent_nodes, :id), :parent_id),
               Sequel.as(Sequel.qualify(:ac_nodes, :id),     :child_id))
    end
    private :relationships_for_collection

    def relationships_for_dataset(dataset)
      child_nodes_clause = join_clause(
        "child_nodes", record_type,
        Sequel.qualify(record_table_name, :id)
      )

      parent_nodes_clause = join_clause(
        "parent_nodes", parent_type,
        Sequel.qualify(record_table_name, key_name)
      )

      dataset.inner_join(*child_nodes_clause).
              inner_join(*parent_nodes_clause).
              select(Sequel.as(Sequel.qualify(:parent_nodes, :id), :parent_id),
                     Sequel.as(Sequel.qualify(:child_nodes, :id),  :child_id))
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
       { Sequel.qualify(nodes_alias, :securable_type) => securable_type,
         Sequel.qualify(nodes_alias, :securable_id)   => id_spec },
       { :table_alias => nodes_alias } ]
    end

    def record_table
      @record_table ||= AccessControl.db[record_table_name]
    end

    def pk_of(securable)
      securable.public_send(@orm.pk_name)
    end

    def associated_record(securable)
      AccessControl.manager.trust { securable.send(association_name) }
    end
  end
end
