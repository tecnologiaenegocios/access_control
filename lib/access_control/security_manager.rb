require 'access_control/exceptions'
require 'access_control/permission_inspector'

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
          inspector(node).has_permission?(permission)
        end
      end
    end

    def verify_access! nodes, permissions
      return if has_access?(nodes, permissions)
      Util.log_missing_permissions(permissions,
                                   permissions_in_context(nodes),
                                   caller)
      raise Unauthorized
    end

    def can_assign_or_unassign? node, role
      return true if unrestrictable_user_logged_in?
      return true if inspector(node).has_permission?('grant_roles')
      return false unless inspector(node).has_permission?('share_own_roles')
      inspector(node).current_roles.include?(role)
    end

    def verify_assignment! node, role
      raise Unauthorized unless can_assign_or_unassign?(node, role)
    end

    def restrict_queries!
      @restrict_queries = true
    end

    def unrestrict_queries!
      @restrict_queries = false
    end

    def restrict_queries?
      return false if unrestrictable_user_logged_in?
      really_restrict_queries?
    end

    def current_user= current_user
      @principal_ids = nil
      @current_user = current_user
    end

    def current_user
      @current_user
    end

    def current_groups= current_groups
      @principal_ids = nil
      @current_groups = current_groups
    end

    def current_groups
      @current_groups || []
    end

    def without_query_restriction
      old_restriction_value = really_restrict_queries?
      unrestrict_queries!
      yield
    ensure
      restrict_queries! if old_restriction_value
    end

  private

    def permissions_in_context *args
      Util.make_set_from_args(*args).inject(Set.new) do |permissions, node|
        permissions | inspector(node).permissions
      end
    end

    def inspector record_or_node
      node = record_or_node
      if record_or_node.respond_to?(:ac_node)
        node = record_or_node.ac_node
      end
      PermissionInspector.new(node)
    end

    def unrestrictable_user_logged_in?
      principal_ids.include?(Principal::UNRESTRICTABLE_ID)
    end

    def current_user_principal_id
      current_user ? current_user.principal.id : Principal.anonymous_id
    end

    def really_restrict_queries?
      @restrict_queries
    end

  end

end
