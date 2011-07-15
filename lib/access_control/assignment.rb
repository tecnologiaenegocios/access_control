require 'access_control/security_manager'

module AccessControl
  class Assignment < ActiveRecord::Base

    set_table_name :ac_assignments

    belongs_to :node, :class_name => 'AccessControl::Node'
    belongs_to :principal, :class_name => 'AccessControl::Principal'
    belongs_to :role, :class_name => 'AccessControl::Role'

    has_many :security_policy_items, :through => :role

    validates_uniqueness_of :role_id, :scope => [:node_id, :principal_id]

    validate :validate_role

    before_save :verify_roles!
    before_destroy :verify_roles!

    named_scope :with_roles, lambda{|roles|
      { :conditions => { :role_id => roles.map(&:id) } }
    }

    # This is a flag that controls the assignment creation.  When the system is
    # doing an automatic assignment this flag is set (this method is called).
    def skip_role_verification!
      @skip_role_verification = true
    end

    # Returns the state of the flag, taking into consideration the flag in the
    # class.
    def skip_role_verification?
      self.class.skip_role_verification? || @skip_role_verification
    end

    def validate_role
      return unless role && node
      if !role.global && node.global?
        errors.add(:role_id, :invalid)
      elsif !role.local && !node.global?
        errors.add(:role_id, :invalid)
      end
    end

    def verify_roles!
      return if skip_role_verification?
      return if node.has_permission?('grant_roles')
      raise Unauthorized unless node.has_permission?('share_own_roles')
      raise Unauthorized unless node.current_roles.map(&:id).include?(role_id)
    end

    def self.securable?
      false
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

    # This flag is used in tests.
    def self.skip_role_verification?
      false
    end

  end
end
