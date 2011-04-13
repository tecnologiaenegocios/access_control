module AccessControl
  class SecurityPolicyItem < ActiveRecord::Base

    set_table_name :ac_security_policy_items
    belongs_to :role, :class_name => 'AccessControl::Role'

    def self.securable?
      false
    end

    def self.mass_manage!(params)
      params ||= {}
      params = params.values if params.is_a?(Hash)
      params.each do |attributes|
        attributes = attributes.with_indifferent_access
        id = attributes.delete(:id)
        destroy = param_to_boolean(attributes.delete(:_destroy))
        if id.present?
          item = find(id)
          next item.destroy if destroy
          next item.update_attributes!(attributes)
        end
        create!(attributes) unless destroy
      end
      Node.clear_global_node_cache
    end

    def self.items_for_management roles
      _all = all
      all_by_permission_and_role = _all.group_by do |i|
        i.permission_name
      end.inject({}) do |h, (k, v)|
        h[k] = v.group_by{|i| i.role_id}
        h
      end
      (PermissionRegistry.all | Set.new(_all.map(&:permission_name))).
        inject({}) do |result, permission_name|
          result[permission_name] = roles.map do |role|
            if all_by_permission_and_role[permission_name] &&
               item = all_by_permission_and_role[permission_name][role.id]
              # item is an array, so get the first (hopefully the only) member.
              next item.first
            end
            SecurityPolicyItem.new(:role_id => role.id,
                                   :permission_name => permission_name)
          end
          result
        end
    end

    private

      def self.param_to_boolean param
        case param
        when 0, '0', 'false', '', false, nil
          false
        else
          true
        end
      end

  end
end
