require 'access_control'

module AccessControl
  class SecurityPolicyItem < Sequel::Model(:ac_security_policy_items)
    dataset_module do
      def with_permissions(permission)
        if permission.is_a?(Set)
          permission = permission.to_a
        end
        filter(:permission => permission)
      end
    end
  end
end
