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
      @current_principals = subjects.inject(Set.new) do |principals, subject|
        raise InvalidSubject unless subject.respond_to?(:ac_principal)
        principals << subject.ac_principal
      end
    end

    def current_principals
      @current_principals ||= Set.new
    end

    def principals
      return [default_principal] if current_principals.empty?
      current_principals
    end

    def can? permissions, nodes
      return true if unrestrictable_user_logged_in?
      nodes = Context.new(nodes).nodes
      permissions = [permissions] unless permissions.respond_to?(:all?)
      permissions.all? do |permission|
        nodes.any? do |node|
          PermissionInspector.new(node).has_permission?(permission)
        end
      end
    end

    def can! permissions, nodes
      return if can?(permissions, nodes)
      Util.log_missing_permissions(permissions,
                                   permissions_in_context(nodes),
                                   roles_in_context(nodes),
                                   caller)
      raise Unauthorized
    end

    def can_assign_or_unassign? node, role
      return true if unrestrictable_user_logged_in?
      return true unless restrict_assignment_or_unassignment?
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

    def permissions_in_context *args
      Context.new(args).nodes.inject(Set.new) do |permissions, node|
        permissions | PermissionInspector.new(node).permissions
      end
    end

    def roles_in_context *args
      Context.new(args).nodes.inject(Set.new) do |roles, node|
        roles | PermissionInspector.new(node).current_roles
      end
    end

    def unrestrictable_user_logged_in?
      principals.include?(UnrestrictablePrincipal.instance)
    end

    # def current_user_principal_id
    #   current_user ? current_user.principal.id : Principal.anonymous_id
    # end

    def really_restrict_queries?
      @restrict_queries
    end

  end

end
