require 'access_control/exceptions'
require 'access_control/principal'
require 'access_control/permission_inspector'

module AccessControl

  class SecurityManager

    def initialize
      @restrict_queries = true
      @use_anonymous = false
    end

    def use_anonymous!
      @use_anonymous = true
    end

    def do_not_use_anonymous!
      @use_anonymous = false
    end

    def use_anonymous?
      !!@use_anonymous
    end

    def current_subjects= subjects
      @current_principals = subjects.inject(Set.new) do |principals, subject|
        raise InvalidSubject unless subject.respond_to?(:ac_principal)
        principals << subject.ac_principal
      end
    end

    def current_principals
      @current_principals ||= Set.new
    end

    def principal_ids
      return [default_principal_id] if current_principals.empty?
      current_principals.map(&:id)
    end

    def has_access? nodes, permissions
      return true if unrestrictable_user_logged_in?
      nodes = SecurityContext.new(nodes).nodes
      permissions = [permissions] unless permissions.respond_to?(:all?)
      permissions.all? do |permission|
        nodes.any? do |node|
          PermissionInspector.new(node).has_permission?(permission)
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
      inspector = PermissionInspector.new(node)
      return true if inspector.has_permission?('grant_roles')
      return false unless inspector.has_permission?('share_own_roles')
      inspector.current_roles.include?(role)
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

    def without_query_restriction
      old_restriction_value = really_restrict_queries?
      unrestrict_queries!
      yield
    ensure
      restrict_queries! if old_restriction_value
    end

  private

    def default_principal_id
      use_anonymous? ? Principal.anonymous_id : UnrestrictablePrincipal::ID
    end

    def permissions_in_context *args
      SecurityContext.new(args).nodes.inject(Set.new) do |permissions, node|
        permissions | PermissionInspector.new(node).permissions
      end
    end

    def unrestrictable_user_logged_in?
      principal_ids.include?(UnrestrictablePrincipal::ID)
    end

    def current_user_principal_id
      current_user ? current_user.principal.id : Principal.anonymous_id
    end

    def really_restrict_queries?
      @restrict_queries
    end

  end

end
