module AccessControl::Model
  class SecurityPolicyItem < ActiveRecord::Base
    set_table_name :ac_security_policy_items
    def self.securable?
      false
    end
  end
end
