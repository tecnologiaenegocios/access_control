require 'access_control/exceptions'
require 'access_control/persistable'

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
        perform_blocking
      else
        perform_unblocking if blocked?
      end
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
        if (result = super)
          setup_parent_nodes()
        end
        result
      end
    end

    def destroy
      AccessControl.transaction do
        Role.unassign_all_at(self)
        inheritance_manager.del_all_parents_with_checks
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

      blocked = blocked?? "blocked": nil

      body = [id, securable_desc, blocked].compact.join(", ")

      "#<AccessControl::Node #{body}>"
    end

    def blocked?
      !!persistent.block
    end

  private

    def perform_blocking
      AccessControl.transaction do
        inheritance_manager.parents.each do |parent|
          inheritance_manager.del_parent(parent)
        end
      end
    end

    def perform_unblocking
      AccessControl.transaction do
        persisted_parent_nodes.each do |parent|
          inheritance_manager.add_parent(parent)
        end
      end
    end

    def setup_parent_nodes
      added_parents = new_persisted_parent_nodes
      deleted_parents = removed_persisted_parent_nodes

      added_parents.each do |parent_node|
        inheritance_manager.add_parent(parent_node)
      end
      deleted_parents.each do |parent_node|
        inheritance_manager.del_parent(parent_node)
      end
    end

    def new_persisted_parent_nodes
      current_parent_nodes = inheritance_manager.parents
      final_parent_nodes   = persisted_parent_nodes
      final_parent_nodes - current_parent_nodes
    end

    def removed_persisted_parent_nodes
      current_parent_nodes = inheritance_manager.parents
      final_parent_nodes   = persisted_parent_nodes
      current_parent_nodes - final_parent_nodes
    end

    def persisted_parent_nodes
      parent_nodes.select(&:persisted?)
    end

    def parent_nodes
      securable_parents.map do |securable_parent|
        AccessControl::Node(securable_parent)
      end
    end

    def securable_parents
      methods = securable_class.inherits_permissions_from
      methods.each_with_object(Set.new) do |method_name, set|
        set.merge(Array[*securable.send(method_name)].compact)
      end
    end
  end
end
