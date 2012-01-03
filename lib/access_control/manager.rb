require 'access_control/exceptions'
require 'access_control/principal'
require 'access_control/permission_inspector'

module AccessControl

  class Manager

    def initialize
      @restrict_queries = true
      @restrict_assignment_or_unassignment = true
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
      @current_principals = Set.new(subjects) do |subject|
        raise InvalidSubject unless subject.respond_to?(:ac_principal)
        subject.ac_principal
      end
    end

    def current_principals
      @current_principals ||= Set.new
    end

    def principals
      return [default_principal] if current_principals.empty?
      current_principals
    end

    def can?(permissions, nodes)
      return true if unrestrictable_user_logged_in?

      inspector       = PermissionInspector.new(nodes)
      permissions_set = Set.new(permissions)

      permissions_set.subset?(inspector.permissions)
    end

    def can!(permissions, nodes)
      return if can?(permissions, nodes)

      inspector           = PermissionInspector.new(nodes)
      granted_permissions = inspector.permissions
      current_roles       = inspector.current_roles

      Util.log_missing_permissions(permissions, granted_permissions,
                                   current_roles, caller)
      raise Unauthorized
    end

    def can_assign_or_unassign?(node, role)
      restriction_enabled = restrict_assignment_or_unassignment? and
                            not unrestrictable_user_logged_in?

      return true unless restriction_enabled

      inspector = PermissionInspector.new(node)
      if inspector.has_permission?('grant_roles')
        true
      else
        user_can_share_roles = inspector.has_permission?('share_own_roles')
        user_can_share_roles && inspector.current_roles.include?(role)
      end

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

    def restrict_assignment_or_unassignment!
      @restrict_assignment_or_unassignment = true
    end

    def unrestrict_assignment_or_unassignment!
      @restrict_assignment_or_unassignment = false
    end

    def restrict_assignment_or_unassignment?
      return false if unrestrictable_user_logged_in?
      @restrict_assignment_or_unassignment
    end

    def without_query_restriction
      old_restriction_value = really_restrict_queries?
      unrestrict_queries!
      yield
    ensure
      restrict_queries! if old_restriction_value
    end

    def without_assignment_restriction
      old_restriction_value = restrict_assignment_or_unassignment?
      unrestrict_assignment_or_unassignment!
      yield
    ensure
      restrict_assignment_or_unassignment! if old_restriction_value
    end

  private

    def default_principal
      use_anonymous? ? Principal.anonymous : UnrestrictablePrincipal.instance
    end

    def unrestrictable_user_logged_in?
      principals.include?(UnrestrictablePrincipal.instance)
    end

    def really_restrict_queries?
      @restrict_queries
    end

  end

end
