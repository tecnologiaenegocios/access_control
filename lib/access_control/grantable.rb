require 'access_control/manager'
require 'access_control/node'

module AccessControl
  class Grantable

    attr_reader :orm

    def initialize(orm)
      @orm = orm
    end

    def ids_with(permissions)
      nodes = Node.granted_for(orm.name, principals, permissions)
      Set.new(nodes.select_values_of_column(:securable_id) - [0])
    end

    def from_class?(permissions)
      Node.granted_for(orm.name, principals, permissions).any? do |node|
        node.securable_id == 0
      end
    end

  private

    def principals
      AccessControl.manager.principals
    end

  end
end
