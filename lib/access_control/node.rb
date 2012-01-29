require 'access_control/exceptions'
require 'access_control/persistable'
require 'access_control/role_propagation'

module AccessControl

  def AccessControl.Node(object)
    if object.kind_of?(AccessControl::Node)
      object
    elsif object.respond_to?(:ac_node)
      object.ac_node
    elsif object.equal?(AccessControl::GlobalRecord.instance)
      AccessControl.global_node
    else
      raise(UnrecognizedSecurable)
    end
  end

  class Node
    require 'access_control/node/class_methods'
    include AccessControl::Persistable
    extend Node::ClassMethods

    delegate_subset :with_type

    def initialize(properties={})
      properties.delete(:securable_type) if properties[:securable_class]
      super(properties)
    end

    def block= value
      if value
        perform_blocking unless blocked?
      else
        perform_unblocking if blocked?
      end
      persistent.block = value
    end

    def global?
      id == AccessControl.global_node_id
    end

    def persist
      AccessControl.transaction do
        if (result = super)
          refresh_parents
        end
        result
      end
    end

    def destroy
      AccessControl.transaction do
        Role.unassign_all_at(self)
        NodeManager.disconnect(self)
        super
      end
    end

    def refresh_parents
      NodeManager.refresh_parents_of(self)
    end

    def can_update!
      NodeManager.can_update!(self)
    end

    def securable
      @securable ||=
        begin
          if global?
            AccessControl::GlobalRecord.instance
          else
            AccessControl.manager.without_query_restriction do
              record = adapted_class[securable_id]
              unless record
                raise NotFoundError,
                      "missing securable #{securable_type}(#{securable_id})"
              end
              record
            end
          end
        end
    end
    attr_writer :securable

    def securable_class=(klass)
      self.securable_type = klass.name
      @securable_class    = klass
    end

    def securable_class
      @securable_class ||= securable_type.constantize
    end

    def inspect
      id = "id: #{self.id.inspect}"
      securable_desc = ""
      if securable_id
        securable_desc = "securable: #{securable_type}(#{securable_id})"
      else
        securable_desc = "securable_type: #{securable_type.inspect}"
      end

      blocked = blocked?? "blocked": nil

      body = [id, securable_desc, blocked].compact.join(", ")

      "#<AccessControl::Node #{body}>"
    end

    def blocked?
      !!persistent.block
    end

  private

    def adapted_class
      @adapted_class ||= ORM.adapt_class(securable_class)
    end

    def perform_blocking
      NodeManager.block(self)
    end

    def perform_unblocking
      NodeManager.unblock(self)
    end
  end
end
