require 'access_control/exceptions'

module AccessControl

  def self.set_security_manager current_controller
    Thread.current[:__security_manager] = SecurityManager.new(
      current_controller
    )
  end

  def self.get_security_manager
    Thread.current[:__security_manager]
  end

  def self.no_security_manager
    Thread.current[:__security_manager] = nil
  end

  class SecurityManager

    attr_writer :restrict_queries

    def initialize controller
      @controller = controller
      @restrict_queries = true
    end

    def principal_ids
      return [Principal.anonymous.id] unless current_user
      @principal_ids ||= current_groups.inject(
        [current_user.principal.id]
      ) do |ids, group|
        ids << group.principal.id
        ids
      end
    end

    def has_access? nodes, permissions
      nodes = [nodes] unless nodes.respond_to?(:any?)
      permissions = [permissions] unless permissions.respond_to?(:all?)
      permissions.all? do |permission|
        nodes.any? do |node|
          node.has_permission?(permission)
        end
      end
    end

    def verify_access! nodes, permissions
      return if has_access?(nodes, permissions)
      Util.log_missing_permissions(nodes, permissions, caller)
      raise Unauthorized
    end

    def restrict_queries?
      !!@restrict_queries
    end

    def permissions_in_context *args
      Util.make_set_from_args(*args).inject(Set.new) do |permissions, node|
        permissions | node.permission_names
      end
    end

    def roles_in_context *args
      Util.make_set_from_args(*args).inject(Set.new) do |roles, node|
        roles | node.current_roles
      end
    end

    private

      def current_user
        @current_user ||= @controller.send(:current_user)
      end

      def current_groups
        @current_groups ||= @controller.send(:current_groups)
      end

  end

end
