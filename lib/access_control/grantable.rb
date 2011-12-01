require 'access_control/manager'
require 'access_control/node'

module AccessControl
  class Grantable

    attr_reader :model

    def initialize(model)
      @model = model
    end

    def ids_with(permissions)
      nodes = Node.granted_for(model.name, principal_ids, permissions)
      Set.new(nodes.map(&:securable_id) - [0])
    end

    def from_class?(permissions)
      Node.granted_for(model.name, principal_ids, permissions).any? do |node|
        node.securable_id == 0
      end
    end

  private

    def principal_ids
      AccessControl.manager.principal_ids
    end

  end
end
