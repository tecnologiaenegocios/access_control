module AccessControl
  class Role
    class Persistent < ActiveRecord::Base
      set_table_name :ac_roles

      extend AccessControl::Ids

      validates_presence_of :name
      validates_uniqueness_of :name

      has_many :persisted_assignments, :foreign_key => 'role_id',
               :class_name => 'AccessControl::Assignment',
               :dependent => :delete_all

      has_many :security_policy_items, :foreign_key => 'role_id',
               :dependent => :destroy,
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

      def assignments=(assignments)
        assignments.each do |assignment|
          hash = hash_assignment(assignment)
          hashed_assignments[hash] ||= build_assignment(assignment)
        end
      end

      def assignments
        current_assignments.to_enum(:each)
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

      def hashed_assignments
        @hashed_assignments ||=
          persisted_assignments.each_with_object(Hash.new) do |assignment, hash|
            hash.store(hash_assignment(assignment), assignment)
          end
      end

      def hash_assignment(assignment)
        [assignment.node, assignment.principal].hash
      end

      def current_assignments
        if new_record?
          @current_assignments ||= Array.new
        else
          @current_assignments ||= persisted_assignments
        end
      end

      def build_assignment(struct)
        properties = {:node => struct.node, :principal => struct.principal}
        current_assignments << persisted_assignments.build(properties)
      end

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
