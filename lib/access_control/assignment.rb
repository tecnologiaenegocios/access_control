module AccessControl
  class Assignment
    include AccessControl::Persistable

    def self.persistent_model
      @persistent_model ||= ORM.adapt_class(Assignment::Persistent)
    end

    delegate_subsets :with_nodes, :with_roles, :assigned_to,
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

    def propagate_to(node)
      node_id = node.kind_of?(Numeric) ? node : node.id

      Assignment.store(:node_id => node_id, :principal_id => self.principal_id,
                       :role_id => self.role_id, :parent_id => self.id)
    end

    def persist
      AccessControl.transaction do
        super.tap do
          propagate_to_node_descendants!
        end
      end
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

    def propagate_to_node_descendants!
      Persistent.propagate_to_descendants([self], node_id)
    end
  end
end
