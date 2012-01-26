require 'access_control'
require 'access_control/dataset_helper'

module AccessControl
  class Role
    class Persistent < Sequel::Model(:ac_roles)

      include AccessControl::DatasetHelper

      def self.create!(properties={})
        new(properties).save(:raise_on_failure => true)
      end

      def self.for_all_permissions(permissions)
        items = SecurityPolicyItem.with_permissions(permissions).to_a
        items_by_role = items.group_by(&:role_id)

        permissions_set = Set.new(permissions)
        accepted_combinations = items_by_role.select do |_, role_items|
          role_permissions = Set.new(role_items, &:permission)

          role_permissions.superset?(permissions_set)
        end
        accepted_ids = Hash[accepted_combinations].keys

        filter(:id => accepted_ids)
      end

      def self.assigned_to(principal, node = nil)
        principal_id = Util.id_of(principal) { AccessControl::Principal(principal) }

        if node
          node_id = Util.id_of(node) { AccessControl::Node(node) }
          related_assignments = Assignment::Persistent.assigned_on(node_id,
                                                                   principal_id)
        else
          related_assignments = Assignment::Persistent.assigned_to(principal_id)
        end
        filter(:id => related_assignments.select(:role_id))
      end

      def self.assigned_at(node, principal = nil)
        return assigned_to(principal, node) if principal

        node_id = Util.id_of(node) { AccessControl::Node(node) }
        filter(:id=>Assignment::Persistent.with_nodes(node_id).select(:role_id))
      end

      def self.default
        with_names(AccessControl.config.default_roles)
      end

      def self.with_names(names)
        if names.kind_of?(Enumerable)
          names = names.to_a
        end
        filter(:name => names)
      end

      def permissions=(permissions)
        @permissions         = Set.new(permissions)
        @added_permissions   = @permissions - current_permissions
        @removed_permissions = current_permissions - @permissions
      end

      def permissions
        @permissions ||= current_permissions
      end

    private

      def after_save
        super
        update_permissions
      end

      def update_permissions
        added_permissions.each do |permission|
          item = SecurityPolicyItem.new(:permission => permission,
                                        :role_id    => self.id)
          item.save(:raise_on_failure => true)
        end

        policy_items.filter(:permission => removed_permissions.to_a).delete

        @added_permissions   = Set.new
        @removed_permissions = Set.new
      end

      def before_destroy
        policy_items.delete
        super
      end

      def policy_items
        SecurityPolicyItem.filter(:role_id => id)
      end

      def current_permissions
        Set.new(policy_items.select_map(:permission))
      end

      def added_permissions
        @added_permissions ||= Set.new
      end

      def removed_permissions
        @removed_permissions ||= Set.new
      end
    end
  end
end
