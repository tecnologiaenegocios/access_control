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

      def on(principal, node)
        principal_id = Util.id_of(principal)
        node_id = Util.id_of(node)

        query_database = Proc.new do
          overlapping(principal_id, node_id).first
        end

        volatile.detect(query_database) do |assignment|
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

    def self.assign_all(roles, principals, nodes,
                        combination = AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.roles                    = roles
      combination.skip_existing_assigments = true

      combination.each(&:persist!)
    end

    def self.unassign_all(roles, principals, nodes,
                          combination=AssignmentCombination.new)
      combination.nodes                    = nodes
      combination.principals               = principals
      combination.roles                    = roles
      combination.only_existing_assigments = true

      combination.each(&:destroy)
    end

    delegate_subsets :assigned_to, :assigned_at, :for_all_permissions,
                     :default, :with_names

    def self.unassign_all_from(principal)
      assigned_to(principal).each do |role|
        role.unassign_from(principal)
      end
    end

    def self.unassign_all_at(node)
      assigned_at(node).each do |role|
        role.unassign_at(node)
      end
    end

    def permissions
      permissions_set.to_enum
    end

    def add_permissions(*names)
      new_permissions = names.to_set - permissions_set
      permissions_set.merge(new_permissions)
      persist_permissions()
      new_permissions
    end

    def del_permissions(*names)
      existent_permissions = names.to_set & permissions_set
      permissions_set.subtract(existent_permissions)
      persist_permissions()
      existent_permissions
    end

    def assign_to(principal, node)
      assign_on(principal, node)
    end

    def assign_at(node, principal)
      assign_on(principal, node)
    end

    def assigned_to?(principal, node)
      assignments.has?(principal, node)
    end

    def assigned_at?(node, principal)
      assigned_to?(principal, node)
    end

    def unassign_from(principal, node = nil)
      if node
        assignments.remove_on(principal, node)
      else
        assignments.remove_from(principal)
      end
    end

    def unassign_at(node, principal = nil)
      if principal
        assignments.remove_on(principal, node)
      else
        assignments.remove_at(node)
      end
    end

    def persist
      persistent.permissions = permissions.to_a
      result = super
      assignments.persist if result
      result
    end

    def destroy
      assignments.destroy
      super
    end

  private

    def assign_on(principal, node)
      principal_id = Util.id_of(principal)
      node_id = Util.id_of(node)

      assignments << Assignment.new(:principal_id => principal_id,
                                    :node_id      => node_id)
    end

    def assignments
      @assignments ||= AssignmentsAssociation.new(self)
    end

    def permissions_set
      @permissions_set ||= persistent.permissions
    end

    def persist_permissions
      persistent.permissions = permissions.to_a
      persistent.save(:raise_on_failure => true)
    end
  end
end
