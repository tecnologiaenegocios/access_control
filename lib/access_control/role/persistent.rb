module AccessControl
  class Role
    class Persistent < ActiveRecord::Base
      set_table_name :ac_roles

      extend AccessControl::Ids

      has_many :persisted_assignments, :foreign_key => 'role_id',
               :class_name => 'AccessControl::Assignment',
               :dependent => :delete_all

      has_many :security_policy_items, :foreign_key => 'role_id',
               :dependent => :delete_all,
               :class_name => 'AccessControl::SecurityPolicyItem'
      private :security_policy_items

      named_scope :local_assignables,
                  :conditions => {:local => true}

      named_scope :global_assignables,
                  :conditions => {:global => true}

      def self.for_all_permissions(permissions)
        items = SecurityPolicyItem.with_permission(permissions)
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
        related_assignments = Assignment.assigned_to(principal)
        if node
          related_assignments = related_assignments.with_nodes(node)
        end
        subquery = related_assignments.column_sql(:role_id)
        scoped(:conditions => "#{quoted_table_name}.id IN (#{subquery})")
      end

      def self.assigned_at(nodes, principal = nil)
        return assigned_to(principal, nodes) if principal

        subquery = Assignment.with_nodes(nodes).column_sql(:role_id)
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
        permissions = Set.new(permissions)
        return if permissions == self.permissions

        missing_permissions = permissions - self.permissions
        add_permissions(missing_permissions)

        extra_permissions = self.permissions - permissions
        remove_permissions(extra_permissions)
      end

      def permissions
        Set.new(security_policy_items, &:permission)
      end

    private

      def add_permissions(permissions)
        permissions.each do |permission|
          security_policy_items.build(:permission => permission)
        end
      end

      def remove_permissions(permissions)
        permissions.each do |permission|
          item = security_policy_items.find_by_permission(permission)
          security_policy_items.delete(item)
        end
      end
    end
  end
end
