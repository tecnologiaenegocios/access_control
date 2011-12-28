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

    def self.assign_all_to(principals, nodes, combination = AssignmentCombination.new)
      combination.nodes                        = nodes
      combination.principals                   = principals
      combination.roles                        = all
      combination.include_existing_assignments = false

      combination.each(&:save!)
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

    def unassign_from(principal, securable=nil)
      if securable
        node = AccessControl::Node(securable)
        item = assignments.find_by_principal_id_and_node_id(principal.id,
                                                            node.id)
        item.destroy if item
      else
        assignments.find_all_by_principal_id(principal.id).each do |item|
          item.destroy
        end
      end
    end

    def assign_permission(permission)
      unless security_policy_items.find_by_permission(permission)
        security_policy_items.create!(:permission => permission)
      end
    end

  private

    def destroy_dependant_assignments
      AccessControl.manager.without_assignment_restriction do
        assignments.each do |assignment|
          assignment.destroy
        end
      end
    end
  end
end
