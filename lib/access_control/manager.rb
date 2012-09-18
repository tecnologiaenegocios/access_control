require 'access_control/exceptions'
require 'access_control/principal'
require 'access_control/permission_inspector'

module AccessControl

  class Manager

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
      @current_principals = Set.new(subjects) do |subject|
        AccessControl::Principal(subject)
      end
    end

    attr_writer :current_principals
    def current_principals
      @current_principals ||= Set.new
    end

    def principals
      return [default_principal] if current_principals.empty?
      current_principals
    end

    def can?(permissions, nodes)
      return true if unrestrictable_user_logged_in? || inside_trusted_block?

      permissions_set = Set[*permissions]

      global_inspector = PermissionInspector.new(AccessControl.global_node)
      inspector        = PermissionInspector.new(nodes)

      return true if permissions_set.subset?(global_inspector.permissions)

      permissions_set.subset?(inspector.permissions)
    end

    def can!(permissions, nodes)
      return if can?(permissions, nodes)

      global_inspector    = PermissionInspector.new(AccessControl.global_node)
      inspector           = PermissionInspector.new(nodes)

      granted_permissions = inspector.permissions |
                            global_inspector.permissions
      current_roles       = inspector.current_roles |
                            global_inspector.current_roles

      AccessControl.logger.unauthorized(
        permissions,
        granted_permissions,
        current_roles,
        nodes,
        principals,
        caller
      )

      raise Unauthorized
    end

    def restrict_queries?
      return false if unrestrictable_user_logged_in?
      really_restrict_queries?
    end
    alias_method :restricting_queries?, :restrict_queries?

    def without_query_restriction
      old_restriction_value = really_restrict_queries?
      unrestrict_queries!
      yield
    ensure
      restrict_queries! if old_restriction_value
    end

    def trust(&block)
      previous_trust_status = inside_trusted_block?
      @inside_trusted_block = true
      without_query_restriction(&block)
    ensure
      @inside_trusted_block = previous_trust_status
    end

    def inside_trusted_block?
      !!@inside_trusted_block
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

    def restrict_queries!
      @restrict_queries = true
    end

    def unrestrict_queries!
      @restrict_queries = false
    end

  end

end
