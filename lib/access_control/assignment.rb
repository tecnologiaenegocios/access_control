require 'access_control/ids'
require 'access_control/manager'

module AccessControl
  class Assignment < ActiveRecord::Base

    extend AccessControl::Ids

    set_table_name :ac_assignments

    belongs_to :principal, :class_name => 'AccessControl::Principal'
    belongs_to :role, :class_name => 'AccessControl::Role'

    has_many :security_policy_items, :through => :role

    validates_presence_of :node_id
    validates_presence_of :role_id
    validates_presence_of :principal_id

    validates_uniqueness_of :role_id, :scope => [:node_id, :principal_id]

    validate :validate_role_locality
    validate :validate_assignment_security

    before_destroy :verify_security_restrictions!

    named_scope :with_roles, lambda {|role|
      { :conditions => { :role_id => role } }
    }

    named_scope :assigned_to, lambda {|principal|
      { :conditions => { :principal_id => principal } }
    }

    named_scope :granting, lambda {|permission|
      ids = Role.for_permission(permission).ids
      { :conditions => { :role_id => ids } }
    }

    named_scope :with_node_id, lambda { |node_id|
      { :conditions => { :node_id => node_id } }
    }

    def self.granting_for_principal(permission, principal)
      granting(permission).assigned_to(principal)
    end

    def node=(node)
      self.node_id = node.id
      @node        = node
    end

    def node
      @node ||= Node.fetch(node_id, nil)
    end

    def validate_role_locality
      return unless role && node
      if !role.global && node.global?
        errors.add(:role_id, :invalid)
      elsif !role.local && !node.global?
        errors.add(:role_id, :invalid)
      end
    end

    def validate_assignment_security
      return unless role && node
      return if skip_assignment_verification?
      errors.add(:role_id, :unassignable) unless can_assign_or_unassign?
    end

    def overlaps?(other)
      other.node_id == node_id && other.role_id == role_id &&
        other.principal_id == principal_id
    end

    def self.items_for_management(node, roles)
      existing_assignments = Assignment.with_node_id(node.id).all
      principals_ids       = existing_assignments.map(&:principal_id)
      role_ids             = roles.map(&:id)

      combination = AssignmentCombination.new(:node => node, :roles => roles)
      combination.principals_ids = principals_ids

      assignments = combination.map do |new_assignment|
        existing_assignment = existing_assignments.detect do |existing|
          new_assignment.overlaps?(existing)
        end
        existing_assignment || new_assignment
      end

      assignments.group_by(&:principal_id)
    end

    def skip_assignment_verification!
      @skip_assignment_verification = true
    end

    def skip_assignment_verification?
      !!@skip_assignment_verification
    end

  private

    def can_assign_or_unassign?
      AccessControl.manager.can_assign_or_unassign?(node, role)
    end

    def verify_security_restrictions!
      AccessControl.manager.verify_assignment!(node, role)
    end

  end
end
