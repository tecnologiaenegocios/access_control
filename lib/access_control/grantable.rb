require 'access_control/manager'
require 'access_control/node'

module AccessControl
  class Grantable

    attr_reader :orm

    def initialize(orm)
      @orm = orm
    end

    def ids_with(permissions)
      nodes = Node.granted_for(orm.name, principal_ids, permissions)
      Set.new(nodes.select_values_of_column(:securable_id) - [0])
    end

    def from_class?(permissions)
      Node.granted_for(orm.name, principal_ids, permissions).any? do |node|
        node.securable_id == 0
      end
    end

  private

    def principal_ids
      AccessControl.manager.principal_ids
    end

  end
end
