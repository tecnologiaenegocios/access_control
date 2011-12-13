require 'access_control/util'

module AccessControl
  class PermissionInspector

    def initialize(node)
      @node = node
    end

    def has_permission?(permission)
      permissions.include?(permission)
    end

    def permissions
      Util.compact_flat_set(current_roles, &:permissions)
    end

    def current_roles
      Util.compact_flat_set(@node.principal_roles)
    end

  end
end
