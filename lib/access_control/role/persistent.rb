module AccessControl
  class Role
    class Persistent < ActiveRecord::Base
      set_table_name :ac_roles

      extend AccessControl::Ids

      validates_presence_of :name
      validates_uniqueness_of :name

      has_many :assignments, :foreign_key => 'role_id',
               :class_name => 'AccessControl::Assignment'

      has_many :security_policy_items,
               :dependent => :destroy,
               :class_name => 'AccessControl::SecurityPolicyItem'

      named_scope :local_assignables,
                  :conditions => {:local => true}

      named_scope :global_assignables,
                  :conditions => {:global => true}

      def self.for_permission(permission)
        ids = SecurityPolicyItem.with_permission(permission).role_ids
        scoped(:conditions => {:id => ids})
      end

      def self.for_all_permissions(permissions)
        SecurityPolicyItem.with_permission(permissions).
          group_by(&:permission).
          values.map(&:role_ids).
          inject(&:&)
      end

      def self.assigned_to(principal, node = nil)
        related_assignments = Assignment.assigned_to(principal)
        if node
          related_assignments = related_assignments.with_nodes(node)
        end
        scoped(:conditions => { :id => related_assignments.role_ids })
      end

      def self.assigned_at(nodes, principal = nil)
        return assigned_to(principal, nodes) if principal

        related_assignments = Assignment.with_nodes(nodes)
        scoped(:conditions => { :id => related_assignments.role_ids })
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

      # def assign_to(principal, node)
      #   if found = find_assignments_of(principal, node)
      #     found
      #   else
      #     assignments.create!(:principal_id => principal.id, :node_id => node.id)
      #   end
      # end

      # def assign_at(node, principal)
      #   assign_to(principal, node)
      # end

      # def assigned_to?(principal, node)
      #   assignments.exists?(:principal_id => principal.id, :node_id => node.id)
      # end

      # def assigned_at?(node, principal)
      #   assigned_to?(principal, node)
      # end

      # def unassign_from(principal, node=nil)
      #   destroy_existing_assignments(:principal => principal, :node => node)
      # end

      # def unassign_at(node, principal=nil)
      #   destroy_existing_assignments(:node => node, :principal => principal)
      # end

    private

      def find_assignments_of(principal, node)
        assignments.find_by_principal_id_and_node_id(principal.id, node.id)
      end

      def destroy_existing_assignments(arguments)
        principal = arguments.delete(:principal)
        node      = arguments.delete(:node)

        items = []
        if principal && node
          items = [find_assignments_of(principal, node)].compact
        elsif  principal && !node
          items = assignments.find_all_by_principal_id(principal.id)
        elsif !principal && node
          items = assignments.find_all_by_node_id(node.id)
        end

        items.each(&:destroy)
      end

    end
  end
end
