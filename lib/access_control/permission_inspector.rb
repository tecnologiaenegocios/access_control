module AccessControl
  class PermissionInspector

    ROLES_THREAD_KEY = "#{name}::roles".freeze

    class RoleSet
      def initialize(roles)
        @roles = Set.new(roles)
      end

      include Enumerable

      attr_reader :roles
      def each(&block)
        return to_enum(__method__) unless block_given?
        roles.each(&block)
      end

      def permissions
        @permissions ||= map(&:permissions).inject(Set.new, :merge)
      end
    end

    def self.roles_on(context, principals)
      cache_key = [context,principals]

      roles = (Thread.current[ROLES_THREAD_KEY] ||= Hash.new)
      roles[cache_key] ||= RoleSet.new(Role.assigned_to(principals, context))
    end

    def self.clear_role_cache
      Thread.current[ROLES_THREAD_KEY] = nil
    end

    attr_reader :principals
    def initialize(nodes_or_securables,
                   principals = AccessControl.manager.principals)
      unless nodes_or_securables.kind_of?(Enumerable)
        nodes_or_securables = [nodes_or_securables]
      end

      @nodes_or_securables = nodes_or_securables
      @principals          = principals
    end

    def context
      @context ||= nodes_or_securables.each_with_object(Set.new) do |item, set|
        node = AccessControl::Node(item)
        if node.persisted?
          set << node
        else
          set.merge(Inheritance.parent_nodes_of(node.securable))
        end
      end
    end

    def has_permission?(permission)
      permissions.include?(permission)
    end

    def permissions
      current_roleset.permissions
    end

    def current_roles
      current_roleset.roles
    end

  private

    attr_reader :nodes_or_securables

    def current_roleset
      PermissionInspector.roles_on(context, principals)
    end
  end
end
