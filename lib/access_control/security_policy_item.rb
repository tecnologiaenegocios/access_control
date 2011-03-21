module AccessControl
  class SecurityPolicyItem < ActiveRecord::Base
    set_table_name :ac_security_policy_items
    belongs_to :role, :class_name => 'AccessControl::Role'
    def self.securable?
      false
    end
  end
end
