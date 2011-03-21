module AccessControl::Model
  class SecurityPolicyItem < ActiveRecord::Base
    set_table_name :ac_security_policy_items
    belongs_to :role, :class_name => 'AccessControl::Model::Role'
    def self.securable?
      false
    end
  end
end
