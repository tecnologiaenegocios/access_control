# vim: fdm=marker
require 'access_control/orm'

module AccessControl
  class Role

    class AssignmentsAssociation# {{{
      attr_reader :owner, :volatile

      def initialize(owner)
        @owner    = owner
        @volatile = []
      end

      def << assignment
        if owner.persisted?
          persist_assignment(assignment)
        else
          volatile << assignment
        end
        self
      end

      def has?(principal, node)
        effective_on(principal, node).present?
      end

      def has_locally?(principal, node)
        on(principal, node).present?
      end

      def persist
        volatile.each { |assignment| persist_assignment(assignment) }
        volatile.clear
      end

      def destroy
        Assignment.with_roles(owner).each { |assignment| assignment.destroy }
      end

      def remove_on(principal, node)
        principal_id = Util.id_of(principal)
        node_id = Util.id_of(node)

        volatile.delete_if do |obj|
          obj.principal_id == principal_id && obj.node_id == node_id
        end
        destroy_subset(overlapping(principal_id, node_id))
      end

      def remove_from(principal)
        principal_id = Util.id_of(principal)

        volatile.delete_if { |obj| obj.principal_id == principal_id }
        destroy_subset(wrap_subset(
          default_persistent_subset.filter(:principal_id => principal_id)
        ))
      end

      def remove_at(node)
        node_id = Util.id_of(node)

        volatile.delete_if { |obj| obj.node_id == node_id }
        destroy_subset(wrap_subset(
          default_persistent_subset.filter(:node_id => node_id)
        ))
      end

    private

      def effective_on(principal, node)
        fetch_assignment(principal, node) do
          subset = default_persistent_subset.assigned_on(node, principal)
          wrap_subset(subset).first
        end
      end

      def on(principal, node)
        fetch_assignment(principal, node) do
          overlapping(principal, node).first
        end
      end

      def fetch_assignment(principal, node, &query)
        principal_id = Util.id_of(principal)
        node_id      = Util.id_of(node)

        volatile.detect(query) do |assignment|
          assignment.principal_id == principal_id &&
            assignment.node_id == node_id
        end
      end

      def overlapping(principal, node)
        if owner.persisted?
          Assignment.overlapping(owner, principal, node)
        else
          []
        end
      end

      def overlapping?(principal, node)
        overlapping(principal, node).first.present?
      end

      def persist_assignment(assignment)
        unless overlapping?(assignment.principal_id, assignment.node_id)
          assignment.role_id = owner.id
          assignment.persist!
        end
      end

      def destroy_subset(wrapped_persistent_subset)
        wrapped_persistent_subset.each { |assignment| assignment.destroy }
      end

      def default_persistent_subset
        Assignment::Persistent.with_roles(owner)
      end

      def wrap_subset(subset)
        Persistable::WrappedSubset.new(Assignment, subset)
      end
    end# }}}

    def self.persistent_model
      @persistent_model ||= ORM.adapt_class(Role::Persistent)
    end

    include Persistable

    def self.assign_default_at(nodes, principals = AccessControl.manager.principals)
      assign_all(default, principals, nodes)
    end

    def self.assign_all(roles, principals, nodes,
                        combination = AssignmentCombination.new)
      principals = Principal.normalize_collection(principals)
      nodes      = Node.normalize_collection(nodes)

      combination.nodes                    = nodes
      combination.principals               = principals
      combination.roles                    = roles
      combination.skip_existing_assigments = true

      combination.each(&:persist!)
    end

    def self.unassign_all(roles, principals, nodes,
                          combination=AssignmentCombination.new)
      principals = Principal.normalize_collection(principals)
      nodes      = Node.normalize_collection(nodes)

      combination.nodes                    = nodes
      combination.principals               = principals
      combination.roles                    = roles
      combination.only_existing_assigments = true

      combination.each(&:destroy)
    end

    delegate_subsets :assigned_to, :globally_assigned_to, :assigned_at,
                     :default, :with_names

    delegate_subset :for_all_permissions do |permissions|
      [permissions.map(&:name)]
    end

    def self.unassign_all_from(principal)
      principal = AccessControl::Principal(principal)

      assigned_to(principal).each do |role|
        role.unassign_from(principal)
      end
    end

    def self.unassign_all_at(node)
      node = AccessControl::Node(node)

      assigned_at(node).each do |role|
        role.unassign_at(node)
      end
    end

    def self.[](name)
      with_names(name).first
    end

    def permissions
      permissions_set.to_enum
    end

    def add_permissions(permissions)
      new_permissions = permissions.to_set - permissions_set
      permissions_set.merge(new_permissions)
      persist_permissions()
      new_permissions
    end

    def del_permissions(permissions)
      existent_permissions = permissions.to_set & permissions_set
      permissions_set.subtract(existent_permissions)
      persist_permissions()
      existent_permissions
    end

    def assign_to(principal, node)
      assign_on(principal, node)
    end

    def globally_assign_to(principal)
      assign_to(principal, AccessControl.global_node)
    end

    def assign_at(node, principal)
      assign_on(principal, node)
    end

    def assigned_to?(principal, node)
      principal_id = Util.id_of(principal) { AccessControl::Principal(principal) }
      node_id      = Util.id_of(node) { AccessControl::Node(node) }

      assignments.has?(principal_id, node_id)
    end

    def globally_assigned_to?(principal)
      locally_assigned_to?(principal, AccessControl.global_node)
    end

    def locally_assigned_to?(principal, node)
      principal = AccessControl::Principal(principal)
      node      = AccessControl::Node(node)

      assignments.has_locally?(principal, node)
    end

    def assigned_at?(node, principal)
      assigned_to?(principal, node)
    end

    def locally_assigned_at?(node, principal)
      locally_assigned_to?(principal, node)
    end

    def unassign_from(principal, node = nil)
      principal_id = Util.id_of(principal) { AccessControl::Principal(principal) }

      if node
        node_id = Util.id_of(node) { AccessControl::Node(node) }
        assignments.remove_on(principal_id, node_id)
      else
        assignments.remove_from(principal_id)
      end
    end

    def globally_unassign_from(principal)
      unassign_from(principal, AccessControl.global_node)
    end

    def unassign_at(node, principal = nil)
      node_id = Util.id_of(node) { AccessControl::Node(node) }
      if principal
        principal_id = Util.id_of(principal) { AccessControl::Principal(principal) }
        assignments.remove_on(principal_id, node_id)
      else
        assignments.remove_at(node_id)
      end
    end

    def persist
      AccessControl.transaction do
        update_persistent_permissions()
        result = super
        assignments.persist if result
        result
      end
    end

    def destroy
      AccessControl.transaction do
        assignments.destroy
        super
      end
    end

  private

    def assign_on(principal, node)
      principal_id = Util.id_of(principal) { AccessControl::Principal(principal) }
      node_id      = Util.id_of(node) { AccessControl::Node(node) }

      assignments << Assignment.new(:principal_id => principal_id,
                                    :node_id      => node_id)
    end

    def assignments
      @assignments ||= AssignmentsAssociation.new(self)
    end

    def permissions_set
      @permissions_set ||=
        Util.compact_flat_set(persistent.permissions) do |permission_name|
          Registry[permission_name]
        end
    end

    def persist_permissions
      update_persistent_permissions()
      persistent.save(:raise_on_failure => true)
    end

    def update_persistent_permissions
      persistent.permissions = permissions.map(&:name)
    end
  end
end
