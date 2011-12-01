require 'access_control/behavior'

module AccessControl
  class SecurityPolicyItem < ActiveRecord::Base

    set_table_name :ac_security_policy_items
    belongs_to :role, :class_name => 'AccessControl::Role'

    named_scope :with_permission, lambda {|permission| {
      :conditions => { :permission => permission }
    }}

    class << self

      def role_ids
        all(:select => "DISTINCT #{quoted_table_name}.role_id").map(&:role_id)
      end

      def mass_manage!(params)
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
        AccessControl.clear_global_node_cache
      end

      def items_for_management roles
        all_by_permission_and_role =
          all.group_by(&:permission).inject({}) do |h, (permission, items)|
            h[permission] = items.group_by(&:role_id)
            h
          end
        permissions = (Registry.all | Set.new(all_by_permission_and_role.keys))
        permissions.inject({}) do |result, permission|
          result[permission] = roles.map do |role|
            if all_by_permission_and_role[permission] &&
                item = all_by_permission_and_role[permission][role.id]
              # item is an array, so get the first (hopefully the only) member.
              next item.first
            end
            SecurityPolicyItem.new(:role_id => role.id,
                                   :permission => permission)
          end
          unless Registry.all.include?(permission)
            Util.log_unregistered_permission(permission)
          end
          result
        end
      end

    private

      def param_to_boolean param
        case param
        when 0, '0', 'false', '', false, nil
          false
        else
          true
        end
      end

    end

  end
end
