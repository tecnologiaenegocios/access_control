module AccessControl::Model
  class Role < ActiveRecord::Base
    set_table_name :ac_roles
    has_many :security_policy_items,
             :dependent => :destroy,
             :class_name => 'AccessControl::Model::SecurityPolicyItem'
    has_many :assignments,
             :dependent => :destroy,
             :class_name => 'AccessControl::Model::Assignment'
    def self.securable?
      false
    end
  end
end
