require 'access_control/node/persistent'
require 'access_control/orm'

# Methods related to AccessControl::Node class, related to record fetching and
# the global node creation/retrieval. The (physical) separation was made for
# organization and readability purposes.

module AccessControl
  module Node::ClassMethods

    def persistent_model
      @persistent_model ||= ORM.adapt_class(Node::Persistent)
    end

    def for_securable(securable)
      orm = ORM.adapt_class(securable.class)
      securable_class = securable.class
      securable_type  = securable_class.name

      if orm.persisted?(securable)
        securable_id = orm.pk_of(securable)

        persistent =
          Node::Persistent.with_type(securable_type).
            filter(:securable_id => securable_id).first

        if persistent
          node = wrap(persistent)
        else
          node = new(:securable_id    => securable_id,
                     :securable_class => securable_class)
        end
      else
        node = new(:securable_class => securable_class)
      end

      node.securable = securable
      node
    end

    def global!
      @global_node = load_global_node()
      @global_node || raise(NoGlobalNode)
    end

    def global
      @global_node ||= create_global_node
    end

    def clear_global_cache
      @global_node = nil
    end

    # Warning: this method is only safe if all models which have STI are loaded
    # before.  The ORM adapter cannot be guaranteed to work reliably in
    # base-class models which wheren't inherited yet with respect to the sti
    # subquery.  By loading all subclasses, the ORM will correctly identify
    # that the base-class model is an STI model and will generate a proper
    # subquery.
    def generate_for(securable_class)
      orm = ORM.adapt_class(securable_class)
      table_name     = orm.table_name
      qualified_pk   = orm.pk_name.qualify(table_name)
      securable_type = securable_class.name

      securables_without_nodes =
        AccessControl.db[table_name].
          select(securable_type, qualified_pk).
          where("`#{table_name}`.`#{orm.pk_name}` IN (#{orm.sti_subquery})").
          join_table(:left, :ac_nodes, {
            qualified_pk              => :ac_nodes__securable_id,
            :ac_nodes__securable_type => securable_type,
          }).
          filter(:ac_nodes__id => nil)

      Node::Persistent.import([:securable_type, :securable_id],
                              securables_without_nodes)
    end

    def normalize_collection(collection)
      collection = [*collection]
      collection.map { |object| AccessControl::Node(object) }
    end
  private

    def create_global_node
      load_global_node || Node.wrap(Node::Persistent.create(global_node_properties))
    end

    def load_global_node
      persistent = Node::Persistent.filter(global_node_properties).first
      if persistent
        Node.wrap(persistent)
      end
    end

    def global_node_properties
      {
        :securable_type => AccessControl.global_securable_type,
        :securable_id   => AccessControl.global_securable_id
      }
    end
  end
end
