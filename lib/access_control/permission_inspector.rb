module AccessControl
  class PermissionInspector

    def initialize(node)
      @node = node
    end

    def has_permission? permission
      permissions.include?(permission)
    end

    def permissions
      memoize('permissions') do
        current_roles.inject(Set.new) do |permissions, role|
          permissions | role.permissions
        end
      end
    end

    def current_roles
      memoize('roles') do
        ancestors.inject(Set.new){|roles, node| roles | node.principal_roles}
      end
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

    def memoize var_name
      var_name = "@__ac_#{var_name}__"
      if memoized = @node.instance_variable_get(var_name)
        return memoized
      end
      @node.instance_variable_set(var_name, yield)
    end

    def ancestors
      @node.ancestors
    end

    def strict_unblocked_ancestors
      @node.strict_unblocked_ancestors
    end

  end
end
