module AccessControl
  class PermissionInspector

    def self.roles_on(context, principals)
      cache_key = [context,principals]

      @roles            ||= Hash.new
      @roles[cache_key] ||= Set.new Role.assigned_to(principals, context)
    end

    def self.clear_role_cache
      @roles = nil
    end

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
      PermissionInspector.roles_on(context, principals)
    end

  end
end
