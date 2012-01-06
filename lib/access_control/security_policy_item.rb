require 'access_control'

module AccessControl
  class SecurityPolicyItem < Sequel::Model(:ac_security_policy_items)
    def_dataset_method(:with_permission) do |permission|
      filter(:permission => permission)
    end
  end
end
