require 'access_control'
require 'access_control/dataset_helper'

module AccessControl
  class Role
    class Persistent < Sequel::Model(:ac_roles)
      include AccessControl::DatasetHelper

      def self.create!(properties={})
        new(properties).save(:raise_on_failure => true)
      end

      dataset_module do
        def for_all_permissions(permissions)
          items = SecurityPolicyItem.with_permissions(permissions).to_a
          items_by_role = items.group_by(&:role_id)

          permissions_set = Set[*permissions]
          accepted_combinations = items_by_role.select do |_, role_items|
            role_permissions = Set.new(role_items, &:permission)

            role_permissions.superset?(permissions_set)
          end
          accepted_ids = Hash[accepted_combinations].keys

          filter(:id => accepted_ids)
        end

        def assigned_to(principals, nodes = nil)
          principals = Principal.normalize_collection(principals)

          if nodes
            ancestors = Node.ancestors_of(*Node.normalize_collection(nodes))
            assignments = Assignment::Persistent
              .assigned_on(ancestors, principals)
          else
            assignments = Assignment::Persistent.assigned_to(principals)
          end

          filter(id: assignments.select(:role_id))
        end

        def globally_assigned_to(principals)
          assigned_to(principals, AccessControl.global_node)
        end

        def assigned_at(nodes, principals = nil)
          return assigned_to(principals, nodes) if principals

          ancestors = Node.ancestors_of(*Node.normalize_collection(nodes))
          assignments = Assignment::Persistent.with_nodes(ancestors)
          filter(id: assignments.select(:role_id))
        end

        def default
          with_names(AccessControl.config.default_roles)
        end

        def with_names(names)
          if names.kind_of?(Enumerable)
            names = names.to_a
          end
          filter(:name => names)
        end
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
