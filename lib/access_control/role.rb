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

    delegate_scopes :assigned_to, :assigned_at, :for_all_permissions

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
      assignments[principal] << node
    end

    def assign_at(node, principal)
      assign_to(principal, node)
    end

    def assigned_to?(principal, node)
      assignments[principal].include?(node)
    end

    def assigned_at?(node, principal)
      assigned_to?(principal, node)
    end

    def unassign_from(principal, node = nil)
      if node
        assignments[principal].delete(node)
      else
        assignments[principal].clear
      end
    end

    def unassign_at(node, principal = nil)
      if principal
        assignments[principal].delete(node)
      else
        assignments.values.each do |nodes|
          nodes.delete(node)
        end
      end
    end

    def persist
      persistent.permissions = permissions.to_a
      persistent.save
    end
  private

    def assignments
      @assignments ||= Hash.new { |hash, key| hash[key] = Set.new }
    end

    def permissions_set
      @permissions_set ||= persistent.permissions
    end

    def destroy_dependant_assignments
      AccessControl.manager.without_assignment_restriction do
        assignments.each do |assignment|
          assignment.destroy
        end
      end
    end
  end
end
