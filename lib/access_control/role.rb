module AccessControl
  class Role

    def self.persistent_model
      Role::Persistent
    end

    include Persistable

    def self.assign_all(principals, nodes, combination = AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.role_ids                 = Persistent.ids
      combination.skip_existing_assigments = true

      combination.each(&:save!)
    end

    def self.unassign_all(principals, nodes, combination=AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.role_ids                 = Persistent.ids
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
      new_permissions
    end

    def remove_permissions(*names)
      existent_permissions = names.to_set & permissions_set
      permissions_set.subtract(existent_permissions)
      existent_permissions
    end

    def assign_to(principal, node)
      unless assigned_to?(principal, node)
        new_assignment = assignments_by_principal[principal].build(:node => node)
        real_assignments << new_assignment
        new_assignments  << new_assignment
      end
    end

    def assign_at(node, principal)
      unless assigned_at?(node, principal)
        new_assignment = assignments_by_node[node].build(:principal => principal)
        real_assignments << new_assignment
        new_assignments  << new_assignment
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
      unassign_from_all  = node.nil? && assignments_by_principal[principal].any?

      if unassign_from_node
        assignment = assignment_on(node, principal)
        remove_assignments(assignment)
      elsif unassign_from_all
        assignments = assignments_by_principal[principal]
        remove_assignments(*assignments)
      end
    end

    def unassign_at(node, principal = nil)
      unassign_from_principal = principal && assigned_at?(node, principal)
      unassign_from_all       = principal.nil? && assignments_by_node[node].any?

      if unassign_from_principal
        assignment = assignment_on(node, principal)
        remove_assignments(assignment)
      elsif unassign_from_all
        assignments = assignments_by_node[node]
        remove_assignments(*assignments)
      end
    end

    def persist
      persistent.permissions = permissions.to_a
      persistent.save
    end

  private

    def assignment_on(node, principal)
      node_id      = node.id
      principal_id = principal.id

      query_database = Proc.new do
        real_assignments.find_by_node_id_and_principal_id(node_id, principal_id)
      end

      new_assignments.detect(query_database) do |assignment|
        assignment.node_id == node_id and
          assignment.principal_id == principal_id
      end
    end

    def assignments_by_principal
      @assignments_by_principal ||= Hash.new do |hash, principal|
        hash[principal] = real_assignments.scoped_by_principal_id(principal.id)
      end
    end

    def assignments_by_node
      @assignments_by_node ||= Hash.new do |hash, node|
        hash[node] = real_assignments.scoped_by_node_id(node.id)
      end
    end

    def new_assignments
      @new_assignments ||= Array.new
    end

    def real_assignments
      persistent.persisted_assignments
    end

    def remove_assignments(*assignments)
      real_assignments.delete(assignments)
      assignments.each do |assignment|
        new_assignments.delete(assignment)
      end
    end

    def permissions_set
      @permissions_set ||= persistent.permissions
    end
  end
end
