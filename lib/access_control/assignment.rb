require 'access_control/security_manager'

module AccessControl
  class Assignment < ActiveRecord::Base

    set_table_name :ac_assignments

    belongs_to :node, :class_name => 'AccessControl::Node'
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

    named_scope :with_roles, lambda{|roles|
      { :conditions => { :role_id => roles.map(&:id) } }
    }

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

    def self.items_for_management(node, roles)
      all(
        :conditions => {:node_id => node.id, :role_id => roles.map(&:id)}
      ).group_by{|a| a.principal_id}.inject({}) do |r, (p_id, assigns)|
        r[p_id] = roles.map do |role|
          if assignment = assigns.detect{|a| a.role_id == role.id}
            next assignment
          end
          new(:role_id => role.id, :node_id => node.id, :principal_id => p_id)
        end
        r
      end
    end

    def skip_assignment_verification!
      @skip_assignment_verification = true
    end

    def skip_assignment_verification?
      !!@skip_assignment_verification
    end

  private

    def can_assign_or_unassign?
      AccessControl.security_manager.can_assign_or_unassign?(node, role)
    end

    def verify_security_restrictions!
      AccessControl.security_manager.verify_assignment!(node, role)
    end

  end
end
