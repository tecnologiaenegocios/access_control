require 'access_control/behavior'
require 'access_control/ids'

module AccessControl
  class SecurityPolicyItem < ActiveRecord::Base

    extend AccessControl::Ids

    set_table_name :ac_security_policy_items
    belongs_to :role, :class_name => 'AccessControl::Role'

    named_scope :with_permission, lambda {|permission| {
      :conditions => { :permission => permission }
    }}

    class << self

      def mass_manage!(params, filtered_roles=[])
        params ||= {}
        params = params.values if params.is_a?(Hash)
        filtered_role_ids = filtered_roles.map(&:id)
        params.each do |attributes|
          attributes = attributes.with_indifferent_access
          destroy = param_to_boolean(attributes.delete(:_destroy))
          next if attributes.empty?
          next if filtered_role_ids.include?(attributes[:role_id].to_i)
          item = get_new_item_or_find_existing_one(attributes)
          next if filtered_role_ids.include?(item.role_id)
          item.attributes = attributes
          next item.destroy if destroy && !item.new_record?
          item.save!
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

      def get_new_item_or_find_existing_one(attributes)
        id = attributes.delete(:id)
        item = id.present?? find(id) : new(attributes)
      end

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
