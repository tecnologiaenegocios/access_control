module AccessControl
  class Role

    def self.persistent_model
      Role::Persistent
    end

    include Persistable

    def self.assign_all(roles, principals, nodes,
                        combination = AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.roles                    = roles
      combination.skip_existing_assigments = true

      combination.each(&:persist!)
    end

    def self.unassign_all(roles, principals, nodes,
                          combination=AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.roles                    = roles
      combination.only_existing_assigments = true

      combination.each(&:destroy)
    end

    delegate_scopes :assigned_to, :assigned_at, :for_all_permissions, :default,
                    :with_names_in, :local_assignables, :global_assignables

    def self.unassign_all_from(principal)
      assigned_to(principal).each do |role|
        role.unassign_from(principal)
      end
    end

    def self.unassign_all_at(node)
      assigned_at(node).each do |role|
        role.unassign_at(node)
      end
    end

    def permissions
      Enumerator.new do |yielder|
        permissions_set.each do |permission|
          yielder.yield(permission)
        end
      end
    end

    def add_permissions(*names)
      new_permissions = names.to_set - permissions_set
      permissions_set.merge(new_permissions)
      persist_permissions()
      new_permissions
    end

    def del_permissions(*names)
      existent_permissions = names.to_set & permissions_set
      permissions_set.subtract(existent_permissions)
      persist_permissions()
      existent_permissions
    end

    def assign_to(principal, node)
      unless assigned_to?(principal, node)
        assign_on(principal, node)
      end
    end

    def assign_at(node, principal)
      unless assigned_at?(node, principal)
        assign_on(principal, node)
      end
    end

    def assigned_to?(principal, node)
      !assignment_on(node, principal).nil?
    end

    def assigned_at?(node, principal)
      assigned_to?(principal, node)
    end

    def unassign_from(principal, node = nil)
      unassign_from_node = node      && assigned_to?(principal, node)
      unassign_from_all  = node.nil? && assignments_by_principal(principal).any?

      if unassign_from_node
        assignment = assignment_on(node, principal)
        remove_assignments(assignment)
      elsif unassign_from_all
        assignments = assignments_by_principal(principal)
        remove_assignments(*assignments)
      end
    end

    def unassign_at(node, principal = nil)
      unassign_from_principal = principal && assigned_at?(node, principal)
      unassign_from_all       = principal.nil? && assignments_by_node(node).any?

      if unassign_from_principal
        assignment = assignment_on(node, principal)
        remove_assignments(assignment)
      elsif unassign_from_all
        assignments = assignments_by_node(node)
        remove_assignments(*assignments)
      end
    end

    def persist
      persistent.permissions = permissions.to_a
      result = super
      if result
        new_assignments.each do |a|
          a.role_id = id
          a.persist!
        end
      end
      result
    end

    def destroy
      real_assignments.each(&:destroy)
      super
    end

  private

    def assignment_on(node, principal)
      node_id      = node.id
      principal_id = principal.id

      query_current = Proc.new do
        real_assignments.detect do |a|
          a.node_id == node_id && a.principal_id == principal_id
        end
      end

      new_assignments.detect(query_current) do |assignment|
        assignment.node_id == node_id and
          assignment.principal_id == principal_id
      end
    end

    def assign_on(principal, node)
      if persisted?
        assignment = existing_assignment_on(principal, node)
      else
        assignment = assign_new_on(principal, node)
      end
    end

    def existing_assignment_on(principal, node)
      assignment = Assignment.store(:role_id => self.id,
                                    :principal_id => principal.id,
                                    :node_id => node.id)
      real_assignments << assignment
      assignment
    end

    def assign_new_on(principal, node)
      assignment = Assignment.new(:node_id => node.id,
                                  :principal_id => principal.id)
      new_assignments << assignment
      assignment
    end

    def assignments_by_principal(principal)
      real_assignments.select do |a|
        a.principal_id == principal.id
      end
    end

    def assignments_by_node(node)
      real_assignments.select do |a|
        a.node_id == node.id
      end
    end

    def new_assignments
      @new_assignments ||= Array.new
    end

    def real_assignments
      @real_assignments ||= Assignment.with_roles(self).map{|r| r}
    end

    def remove_assignments(*assignments)
      assignments.each do |assignment|
        new_assignments.delete(assignment)
        real_assignments.detect{|r| r == assignment}.destroy
        real_assignments.delete(assignment)
      end
    end

    def permissions_set
      @permissions_set ||= persistent.permissions
    end

    def persist_permissions
      persistent.permissions = permissions.to_a
      persistent.save!
    end
  end
end
