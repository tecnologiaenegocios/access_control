require 'access_control/exceptions'
require 'access_control/ids'
require 'access_control/inheritance'
require 'access_control/configuration'

module AccessControl

  def AccessControl.Node(object)
    if object.kind_of? Node
      object
    else
      object.ac_node
    end
  end

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
      blocked.with_type(securable_type)
    end

    def assignments_with_roles(filter_roles)
      assignments.with_roles(filter_roles)
    end

    def global?
      id == AccessControl.global_node_id
    end

    after_create :set_default_roles
    before_destroy :destroy_dependant_assignments

    def securable
      securable_class.unrestricted_find(securable_id)
    end

    attr_writer :securable_class
    def securable_class
      @securable_class ||= securable_type.constantize
    end

  private

    def destroy_dependant_assignments
      AccessControl.manager.without_assignment_restriction do
        assignments.each(&:destroy)
      end
    end

    def set_default_roles
      AccessControl.config.default_roles_on_create.each do |role_name|
        next unless role = Role.find_by_name(role_name)

        AccessControl.manager.principal_ids.each do |principal_id|
          r = assignments.build(:role_id => role.id,
                                :principal_id => principal_id)
          r.skip_assignment_verification!
          r.save!
        end
      end
    end
  end
end
