module AccessControl
  class PermissionInspector

    attr_reader :principals, :context
    def initialize(nodes_or_securables, principals = AccessControl.manager.principals)
      self.context = nodes_or_securables
      @principals  = principals
    end

    def context=(nodes_or_securables)
      unless nodes_or_securables.kind_of?(Enumerable)
        nodes_or_securables = [nodes_or_securables]
      end

      @context = Set.new(nodes_or_securables) do |item|
        node = AccessControl::Node(item)
        node.persisted?? node : Node::InheritanceManager.parents_of(node.id)
      end
    end

    def has_permission?(permission)
      permissions.include?(permission)
    end

    def permissions
      Util.compact_flat_set(current_roles, &:permissions)
    end

    def current_roles
      @current_roles ||= Role.assigned_to(principals, context).to_set
    end

  end
end
