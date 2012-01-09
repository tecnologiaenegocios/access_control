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

    def persist
      super.tap do
        propagate_to_node_descendants!
      end
    end

    def destroy
      super.tap do
        destroy_child_assignments!
      end
    end

    def overlaps?(other)
      other.node_id == node_id && other.role_id == role_id &&
        other.principal_id == principal_id
    end

  private

    def destroy_child_assignments!
      Assignment.children_of(self).each(&:destroy)
    end

    def propagate_to_node_descendants!
      common_properties = { :role_id => role_id, :principal_id => principal_id,
                            :parent_id => id }

       node_descendants.each do |node_descendant_id|
        new_assignment_properties =
          common_properties.merge(:node_id => node_descendant_id)

        new_assignment = Assignment.new(new_assignment_properties)
        new_assignment.persist
      end
    end

    def node_descendants
      Node::InheritanceManager.child_ids_of(node_id)
    end

  end
end
