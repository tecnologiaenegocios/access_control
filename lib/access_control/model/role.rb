module AccessControl::Model
  class Role < ActiveRecord::Base
    set_table_name :ac_roles
    has_many :security_policy_items1,
             :class_name => 'AccessControl::Model::SecurityPolicyItem'
    def self.securable?
      false
    end
  end
end
