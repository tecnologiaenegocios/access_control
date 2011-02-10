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

    def initialize controller
      @controller = controller
    end

    def principal_ids
      @principal_ids ||= current_groups.inject(
        [current_user.principal.id]
      ) do |ids, group|
        ids << group.principal.id
        ids
      end
    end

    def has_access? node, permissions
      permissions = [permissions] unless permissions.respond_to?(:all?)
      permissions.all? do |permission|
        node.has_permission?(permission)
      end
    end

    def verify_access! nodes, permissions
      raise Unauthorized unless has_access?(nodes, permissions)
    end

    private

      def current_user
        @current_user ||= @controller.current_user
      end

      def current_groups
        @current_groups ||= @controller.current_groups
      end

  end

end
