module AccessControl
  class Grantable

    attr_reader :model

    def initialize(model)
      @model = model
    end

    def ids_with(permissions, filter=nil)
      principal_ids = AccessControl.security_manager.principal_ids
      if filter
        nodes = Node.granted_for(model.name,
                                 principal_ids,
                                 permissions,
                                 :securable_id => filter.to_a)
      else
        nodes = Node.granted_for(model.name, principal_ids, permissions)
      end
      Set.new(nodes.map(&:securable_id) - [0])
    end
  end
end
