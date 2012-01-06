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
      securable_id    = securable.id
      securable_class = securable.class
      type            = securable_class.name

      persistent = Node::Persistent.with_type(type).
                                    find_by_securable_id(securable_id)
      if persistent
        wrap(persistent)
      else
        new(:securable_id    => securable_id,
            :securable_class => securable_class)
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
  end
end
