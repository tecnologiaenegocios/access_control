module AccessControl::Model
  class Role < ActiveRecord::Base
    set_table_name :ac_roles
    has_many :security_policy_items,
             :class_name => 'AccessControl::Model::SecurityPolicyItem'
    def securable?
      false
    end
  end
end
