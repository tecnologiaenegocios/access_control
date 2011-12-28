module AccessControl
  class PermissionInspector

    attr_reader :principals, :node
    def initialize(node, principals = AccessControl.manager.principals)
      @node       = node
      @principals = principals
    end

    def has_permission?(permission)
      permissions.include?(permission)
    end

    def permissions
      Util.compact_flat_set(current_roles, &:permissions)
    end

    def current_roles
      Role.assigned_to(principals, node.unblocked_ancestors)
    end

  end
end
