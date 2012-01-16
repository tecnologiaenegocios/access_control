require 'access_control/node_manager'

module AccessControl
  class NodeManager
    def initialize(node)
      @node = node
    end

    def assign_default_roles
      Role.assign_all(Role.default, manager.principals, @node)
    end

    def can_update!
      manager.can!(update_permissions, @node)
    end

    def refresh_parents
      @node.refresh_parents
    end

  private

    def manager
      AccessControl.manager
    end

    def update_permissions
      securable_class.permissions_required_to_update
    end

    def securable_class
      @node.securable_class
    end
  end
end
