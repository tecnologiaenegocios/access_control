module AccessControl
  class PermissionInspector

    def initialize(node)
      @node = node
    end

    def has_permission? permission
      permissions.include?(permission)
    end

    def permissions
      @permissions ||= current_roles.inject(Set.new) do |permissions, role|
        permissions | role.permissions
      end
    end

    def current_roles
      ancestors.inject(Set.new){|roles, node| roles | node.principal_roles}
    end

    def inherited_roles_for_all_principals(filter_roles)
      strict_unblocked_ancestors.inject({}) do |results, node|
        node.assignments_with_roles(filter_roles).each do |a|
          results[a.principal_id] ||= {}
          (results[a.principal_id][a.role_id] ||= Set.new).
            add(node.global? ? 'global' : 'inherited')
        end
        results
      end
    end

  private

    def ancestors
      @node.ancestors
    end

    def strict_unblocked_ancestors
      @node.strict_unblocked_ancestors
    end

  end
end
