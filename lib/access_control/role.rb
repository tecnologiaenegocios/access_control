require 'access_control/ids'

module AccessControl
  class Role < ActiveRecord::Base

    extend AccessControl::Ids

    set_table_name :ac_roles
    has_many :security_policy_items,
             :dependent => :destroy,
             :class_name => 'AccessControl::SecurityPolicyItem'

    # This association is not marked as `:dependent => :destroy` because the
    # destruction of the dependent items is done explicitly in a callback
    # below.
    has_many :assignments,
             :class_name => 'AccessControl::Assignment'

    validates_presence_of :name
    validates_uniqueness_of :name

    before_destroy :destroy_dependant_assignments

    named_scope :local_assignables,
                :conditions => {:local => true}

    named_scope :global_assignables,
                :conditions => {:global => true}

    named_scope :for_permission, lambda {|permission|
      ids = SecurityPolicyItem.with_permission(permission).role_ids
      { :conditions => { :id => ids } }
    }

    def self.assigned_to(principal, node = nil)
      related_assignments = Assignment.assigned_to(principal)
      if node
        related_assignments = related_assignments.with_nodes(node)
      end
      scoped(:conditions => { :id => related_assignments.role_ids })
    end

    def self.assigned_at(nodes, principal = nil)
      related_assignments = Assignment.with_nodes(nodes)
      if principal
        related_assignments = related_assignments.assigned_to(principal)
      end
      scoped(:conditions => { :id => related_assignments.role_ids })
    end

    def self.assign_all_to(principals, nodes, combination = AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.role_ids                 = ids
      combination.skip_existing_assigments = true

      combination.each(&:save!)
    end

    def self.unassign_all_from(principals, nodes, restrict=true,
                               combination=AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.role_ids                 = ids
      combination.only_existing_assigments = true

      if restrict
        combination.each(&:destroy)
      else
        AccessControl.manager.without_assignment_restriction do
          combination.each(&:destroy)
        end
      end
    end

    def self.default
      with_names_in(AccessControl.config.default_roles)
    end

    def self.with_names_in(names)
      if names.kind_of?(Enumerable)
        names = names.to_a
      end
      scoped_by_name(names)
    end

    def permissions
      Util.flat_set(security_policy_items, &:permission)
    end

    def assign_to(principal, securable)
      node = AccessControl::Node(securable)
      if found = assignments.find_by_principal_id_and_node_id(principal.id,
                                                              node.id)
        return found
      end
      assignments.create!(:principal_id => principal.id, :node_id => node.id)
    end

    def assigned_to?(principal, securable)
      node = AccessControl::Node(securable)
      assignments.exists?(:principal_id => principal, :node_id => node)
    end

    def unassign_from(principal, node=nil)
      if node
        destroy_existing_assignment_of(principal, node)
      else
        assignments.find_all_by_principal_id(principal.id).each do |item|
          item.destroy
        end
      end
    end

    def unassign_at(node, principal=nil)
      if principal
        destroy_existing_assignment_of(principal, node)
      else
        assignments.find_all_by_node_id(node.id).each { |item| item.destroy }
      end
    end

    def assign_permission(permission)
      unless security_policy_items.find_by_permission(permission)
        security_policy_items.create!(:permission => permission)
      end
    end

  private

    def destroy_existing_assignment_of(principal, node)
      if item = assignments.
          find_by_principal_id_and_node_id(principal.id, node.id)
        item.destroy
      end
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
