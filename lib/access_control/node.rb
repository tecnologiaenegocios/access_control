require 'access_control/exceptions'
require 'access_control/ids'
require 'access_control/inheritance'

module AccessControl
  class Node < ActiveRecord::Base

    extend AccessControl::Ids

    set_table_name :ac_nodes

    has_many(
      :principal_assignments,
      :foreign_key => :node_id,
      :class_name => 'AccessControl::Assignment'
    )

    reflections[:principal_assignments].instance_eval do

      def options
        principal_ids = AccessControl.manager.principal_ids
        principal_ids = principal_ids.first if principal_ids.size == 1
        @options.merge(:conditions => {:principal_id => principal_ids})
      end

      def sanitized_conditions
        # Since our options aren't constant in the reflection life cycle, never
        # cache conditions in this instance (the reflection instance).  So,
        # options are evaluated always. (The default implementation caches the
        # options in a instance variable).
        #
        # It took me a long time debugging to find out why the specs concerning
        # the Node class passed when run in isolation but not when all specs
        # were ran together in a bulk.
        @sanitized_conditions = klass.send(:sanitize_sql, options[:conditions])
      end

    end

    # This association is not marked as `:dependent => :destroy` because the
    # dependent destruction is done explicitly in a `before_destroy` callback
    # below.
    has_many(
      :assignments,
      :foreign_key => :node_id,
      :class_name => 'AccessControl::Assignment'
    )

    accepts_nested_attributes_for :assignments, :allow_destroy => true

    has_many(
      :principal_roles,
      :through => :principal_assignments,
      :source => :role
    )

    named_scope :with_type, lambda {|securable_type| {
      :conditions => { :securable_type => securable_type }
    }}

    named_scope :blocked,   :conditions => { :block => true }
    named_scope :unblocked, :conditions => { :block => false }

    def block= value
      AccessControl.manager.can!('change_inheritance_blocking', self)
      self[:block] = value
    end

    def self.granted_for(securable_type, principal_ids, permissions)
      with_type(securable_type).with_ids(
        Assignment.granting_for_principal(permissions, principal_ids).node_ids
      )
    end

    def self.blocked_for(securable_type)
      find_all_by_securable_type_and_block(securable_type, true)
    end

    def assignments_with_roles(filter_roles)
      assignments.with_roles(filter_roles)
    end

    def global?
      id == AccessControl.global_node_id
    end

    def unblocked_ancestors
      Set.new([self]) | strict_unblocked_ancestors
    end

    def strict_unblocked_ancestors
      unblocked_parents.
        inject(Set.new([AccessControl.global_node])) do |ancestors, parent|
          ancestors | parent.unblocked_ancestors
        end
    end

    def ancestors
      Set.new([self]) | strict_ancestors
    end

    def strict_ancestors
      parents.inject(Set.new([AccessControl.global_node])) do |ancestors, parent|
        ancestors | parent.ancestors
      end
    end

    def securable
      securable_class.unrestricted_find(securable_id)
    end

    after_create :set_default_roles
    before_destroy :destroy_dependant_assignments

  private

    def destroy_dependant_assignments
      AccessControl.manager.without_assignment_restriction do
        assignments.each do |assignment|
          assignment.destroy
        end
      end
    end

    def set_default_roles
      AccessControl.config.default_roles_on_create.each do |role|
        next unless role = Role.find_by_name(role)
        AccessControl.manager.principal_ids.each do |principal_id|
          r = assignments.build(:role_id => role.id,
                                :principal_id => principal_id)
          r.skip_assignment_verification!
          r.save!
        end
      end
    end

    def parents
      return Set.new unless can_inherit?
      securable_class.inherits_permissions_from.inject(Set.new) do |p, assoc|
        p | self.class.get_nodes_from(securable.send(assoc))
      end
    end

    def self.get_nodes_from(object)
      object ? Context.new(object).nodes : Set.new
    end

    def unblocked_parents
      block ? Set.new : parents
    end

    def can_inherit?
      securable_class.include?(Inheritance)
    end

    def securable_class
      securable_type.constantize
    end

  end
end
