module AccessControl
  class Role
    class Persistent < ActiveRecord::Base
      set_table_name :ac_roles

      extend AccessControl::Ids

      named_scope :local_assignables,
                  :conditions => {:local => true}

      named_scope :global_assignables,
                  :conditions => {:global => true}

      def self.for_all_permissions(permissions)
        items = SecurityPolicyItem.with_permission(permissions).to_a
        items_by_role = items.group_by(&:role_id)

        permissions_set = Set.new(permissions)
        accepted_combinations = items_by_role.select do |_, role_items|
          role_permissions = Set.new(role_items, &:permission)

          role_permissions.superset?(permissions_set)
        end
        accepted_ids = Hash[accepted_combinations].keys

        scoped(:conditions => {:id => accepted_ids})
      end

      def self.assigned_to(principal, node = nil)
        if node
          related_assignments = Assignment::Persistent.assigned_on(node,
                                                                   principal)
        else
          related_assignments = Assignment::Persistent.assigned_to(principal)
        end
        subquery = related_assignments.select(:role_id).sql
        scoped(:conditions => "#{quoted_table_name}.id IN (#{subquery})")
      end

      def self.assigned_at(nodes, principal = nil)
        return assigned_to(principal, nodes) if principal

        subquery = Assignment::Persistent.with_nodes(nodes).select(:role_id).sql
        scoped(:conditions => "#{quoted_table_name}.id IN (#{subquery})")
      end

      def self.default
        with_names_in(AccessControl.config.default_roles)
      end

      def self.with_names_in(names)
        if names.kind_of?(Enumerable)
          names = names.to_a
        end
        scoped_by_name(names)
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

      after_save :update_permissions

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

      before_destroy :annihilate_permissions

      def annihilate_permissions
        policy_items.delete
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
