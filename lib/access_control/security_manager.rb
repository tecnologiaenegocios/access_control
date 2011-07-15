require 'access_control/exceptions'

module AccessControl

  SM_THREAD_KEY = :ac_security_manager

  def self.security_manager
    Thread.current[SM_THREAD_KEY] ||= SecurityManager.new
  end

  def self.no_security_manager
    Thread.current[SM_THREAD_KEY] = nil
  end

  class SecurityManager

    def initialize
      @restrict_queries = true
    end

    def principal_ids
      @principal_ids ||= current_groups.
        map{|group| group.principal.id}.
        push(current_user_principal_id).
        uniq
    end

    def has_access? nodes, permissions
      return true if unrestrictable_user_logged_in?
      nodes = [nodes] unless nodes.respond_to?(:any?)
      permissions = [permissions] unless permissions.respond_to?(:all?)
      permissions.all? do |permission|
        nodes.any? do |node|
          as_node(node).has_permission?(permission)
        end
      end
    end

    def verify_access! nodes, permissions
      return if has_access?(nodes, permissions)
      Util.log_missing_permissions(nodes, permissions, caller)
      raise Unauthorized
    end

    def restrict_queries!
      @restrict_queries = true
    end

    def unrestrict_queries!
      @restrict_queries = false
    end

    def restrict_queries?
      @restrict_queries
    end

    def permissions_in_context *args
      Util.make_set_from_args(*args).inject(Set.new) do |permissions, node|
        permissions | as_node(node).permissions
      end
    end

    def roles_in_context *args
      Util.make_set_from_args(*args).inject(Set.new) do |roles, node|
        roles | as_node(node).current_roles
      end
    end

    def current_user= current_user
      @current_user = current_user
    end

    def current_user
      @current_user
    end

    def current_groups= current_groups
      @current_groups = current_groups
    end

    def current_groups
      @current_groups || []
    end

    def without_query_restriction
      old_restriction_value = restrict_queries?
      unrestrict_queries!
      result = yield
      restrict_queries! if old_restriction_value
      result
    end

  private

    def as_node record_or_node
      if record_or_node.respond_to?(:has_permission?) ||
         record_or_node.respond_to?(:permissions) ||
         record_or_node.respond_to?(:current_roles)
        return record_or_node
      end
      # Probably a record.
      record_or_node.ac_node
    end

    def unrestrictable_user_logged_in?
      principal_ids.include?(Principal::UNRESTRICTABLE_ID)
    end

    def current_user_principal_id
      current_user ? current_user.principal.id : Principal.anonymous_id
    end

  end

end
