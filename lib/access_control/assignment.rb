module AccessControl
  class Assignment
    include AccessControl::Persistable

    def self.persistent_model
      @persistent_model ||= ORM.adapt_class(Assignment::Persistent)
    end

    delegate_subsets :with_nodes, :with_roles, :assigned_to,
                     :assigned_on, :overlapping, :effective, :real

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

    def persist
      super.tap do
        propagate_to_node_descendants!
      end
    end

    def overlaps?(other)
      other.node_id == node_id && other.role_id == role_id &&
        other.principal_id == principal_id
    end

    private

    def propagate_to_node_descendants!
      common_properties = { :role_id => role_id, :principal_id => principal_id,
                            :parent_id => id }

      new_assignments_properties = node_descendants.map do |node_descendant_id|
        common_properties.merge(:node_id => node_descendant_id)
      end

      Assignment::Persistent.multi_insert(new_assignments_properties)
    end

    def node_descendants
      Node::InheritanceManager.descendant_ids_of(node_id)
    end

  end
end
