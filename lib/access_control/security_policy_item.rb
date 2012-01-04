require 'access_control/behavior'
require 'access_control/ids'

module AccessControl
  class SecurityPolicyItem < ActiveRecord::Base

    extend AccessControl::Ids

    set_table_name :ac_security_policy_items
    belongs_to :role, :class_name => 'AccessControl::Role'

    named_scope :with_permission, lambda { |permission|
      { :conditions => { :permission => permission } }
    }

  end
end
