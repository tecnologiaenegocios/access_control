require 'access_control/assignment'
require 'access_control/security_policy_item'
require 'access_control/security_manager'

module AccessControl
  class Role < ActiveRecord::Base
    set_table_name :ac_roles
    has_many :security_policy_items,
             :dependent => :destroy,
             :class_name => SecurityPolicyItem.name
    has_many :assignments,
             :dependent => :destroy,
             :class_name => Assignment.name

    validates_uniqueness_of :name

    named_scope :local_assignables,
                :conditions => {:local => true}

    named_scope :global_assignables,
                :conditions => {:global => true}

    def self.securable?
      false
    end
  end
end
