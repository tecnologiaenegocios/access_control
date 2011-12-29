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
      return assigned_to(principal, nodes) if principal

      related_assignments = Assignment.with_nodes(nodes)
      scoped(:conditions => { :id => related_assignments.role_ids })
    end

    def self.assign_all(principals, nodes, combination = AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.role_ids                 = ids
      combination.skip_existing_assigments = true

      combination.each(&:save!)
    end

    def self.unassign_all(principals, nodes, combination=AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.role_ids                 = ids
      combination.only_existing_assigments = true

      combination.each(&:destroy)
    end

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
      permissions_set.to_enum
    end

    def add_permissions(*names)
      new_permissions = names.to_set - permissions_set
      return unless new_permissions.any?

      attributes = new_permissions.map { |p| {:permission => p} }
      security_policy_items.build(attributes)
      flush_permissions()
    end

    def remove_permissions(*names)
      valid_names = names.to_set & permissions_set
      return unless valid_names.any?

      items = valid_names.map do |name|
        security_policy_items.detect { |item| item.permission == name }
      end

      self.security_policy_items -= items
      flush_permissions()
    end

    def assign_to(principal, node)
      if found = find_assignments_of(principal, node)
        found
      else
        assignments.create!(:principal_id => principal.id, :node_id => node.id)
      end
    end

    def assign_at(node, principal)
      assign_to(principal, node)
    end

    def assigned_to?(principal, node)
      assignments.exists?(:principal_id => principal.id, :node_id => node.id)
    end

    def assigned_at?(node, principal)
      assigned_to?(principal, node)
    end

    def unassign_from(principal, node=nil)
      destroy_existing_assignments(:principal => principal, :node => node)
    end

    def unassign_at(node, principal=nil)
      destroy_existing_assignments(:node => node, :principal => principal)
    end

  private
    def flush_permissions
      @permissions_set = nil
    end

    def permissions_set
      @permissions_set ||= Set.new(security_policy_items, &:permission)
    end

    def find_assignments_of(principal, node)
      assignments.find_by_principal_id_and_node_id(principal.id, node.id)
    end

    def destroy_existing_assignments(arguments)
      principal = arguments.delete(:principal)
      node      = arguments.delete(:node)

      items = []
      if principal && node
        items = [find_assignments_of(principal, node)].compact
      elsif  principal && !node
        items = assignments.find_all_by_principal_id(principal.id)
      elsif !principal && node
        items = assignments.find_all_by_node_id(node.id)
      end

      items.each(&:destroy)
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
