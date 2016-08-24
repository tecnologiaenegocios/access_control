module AccessControl
  class Assignment
    include AccessControl::Persistable

    def self.persistent_model
      @persistent_model ||= ORM.adapt_class(Assignment::Persistent)
    end

    delegate_subsets :at_nodes, :of_roles, :to_principals,
                     :assigned_on, :overlapping, :effective, :real,
                     :children_of

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

    def effective?
      not real?
    end

    def real?
      persistent.parent_id.nil?
    end

    def destroy
      AccessControl.transaction do
        super.tap do
          destroy_child_assignments!
        end
      end
    end

    def overlaps?(other)
      other.node_id == node_id && other.role_id == role_id &&
        other.principal_id == principal_id
    end

  private

    def destroy_child_assignments!
      Assignment::Persistent.destroy_children_of(id)
    end
  end
end
