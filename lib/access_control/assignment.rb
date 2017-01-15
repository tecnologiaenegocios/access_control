module AccessControl
  class Assignment
    include AccessControl::Persistable

    def self.persistent_model
      @persistent_model ||= ORM.adapt_class(Assignment::Persistent)
    end

    delegate_subsets :with_nodes, :with_roles, :assigned_to,
                     :assigned_on, :overlapping

    def node=(node)
      self.node_id = node.id
      @node        = node
    end

    def node
      @node ||= Node.fetch(node_id, nil)
    end

    def principal=(principal)
      self.principal_id = principal.id
      @principal        = principal
    end

    def principal
      @principal ||= Principal.fetch(principal_id, nil)
    end

    def overlaps?(other)
      other.node_id == node_id && other.role_id == role_id &&
        other.principal_id == principal_id
    end
  end
end
