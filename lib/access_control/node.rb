require 'access_control/exceptions'
require 'access_control/persistable'

module AccessControl

  def AccessControl.Node(object)
    if object.kind_of?(AccessControl::Node)
      object
    elsif object.respond_to?(:ac_node)
      object.ac_node
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
      AccessControl.manager.can!('change_inheritance_blocking', self)
      persistent.block = value
    end

    def global?
      id == AccessControl.global_node_id
    end

    attr_writer :inheritance_manager
    def inheritance_manager
      @inheritance_manager ||= InheritanceManager.new(self)
    end

    def persist
      AccessControl.transaction do
        performing_update = persisted?
        super
        setup_parent_nodes() unless performing_update
      end
    end

    def destroy
      AccessControl.transaction do
        Role.unassign_all_at(self)
        inheritance_manager.del_all_parents
        inheritance_manager.del_all_children
        super
      end
    end

    def securable
      @securable ||= securable_class.unrestricted_find(securable_id)
    end

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

      blocked = block ? "blocked": nil

      body = [id, securable_desc, blocked].compact.join(", ")

      "#<AccessControl::Node #{body}>"
    end

  private

    def setup_parent_nodes
      securable_parents = securable_class.inherits_permissions_from.map do |method_name|
        securable.send(method_name)
      end

      parent_nodes = securable_parents.map do |securable_parent|
        AccessControl::Node(securable_parent)
      end

      parent_nodes.select!(&:persisted?)

      parent_nodes.each do |parent_node|
        inheritance_manager.add_parent(parent_node)
      end
    end
  end
end
