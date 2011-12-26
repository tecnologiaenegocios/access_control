# Methods related to AccessControl::Node class, related to record fetching and
# the global node creation/retrieval. The (physical) separation was made for
# organization and readability purposes.

module AccessControl
  module Node::ClassMethods

    delegated_scopes = %w[with_type blocked unblocked granted_for blocked_for
                          all]

    delegated_scopes.each do |scope_name|
      define_method(scope_name) do |*args|
        scope = Node::Persistent.public_send(scope_name, *args)
        Node::WrapperScope.new(scope)
      end
    end

    def fetch(id, default_value = marker)
      found = Node::Persistent.find_by_id(id)
      return wrap(found) if found

      return yield if block_given?

      default_value.tap do |value|
        raise NotFoundError if value.eql?(marker)
      end
    end

    def store(properties)
      if securable_class = properties.delete(:securable_class)
        properties[:securable_type] = securable_class.name
      end

      persistent = Node::Persistent.new(properties)

      wrap(persistent).tap do |node|
        node.securable_class = securable_class if securable_class
        node.persist
      end
    end

    def has?(id)
      Node::Persistent.exists?(id)
    end

    def wrap(object)
      allocate.tap do |new_node|
        new_node.instance_variable_set("@persistent", object)
      end
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

  private

    def create_global_node
      load_global_node || Node.wrap(Node::Persistent.create!(global_node_properties))
    end

    def load_global_node
      persistent = Node::Persistent.first(:conditions => global_node_properties)
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

    def marker
      @marker ||= Object.new
    end

  end
end
