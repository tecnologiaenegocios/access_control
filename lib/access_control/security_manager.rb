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
      return [Model::Principal.anonymous.id] unless current_user
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

    def restrict_queries?
      !!@restrict_queries
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
