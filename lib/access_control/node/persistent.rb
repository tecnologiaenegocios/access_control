require 'access_control/node'

module AccessControl
  class Node::Persistent < ActiveRecord::Base
    set_table_name 'ac_nodes'

    extend AccessControl::Ids

    named_scope :with_type, lambda {|securable_type| {
      :conditions => { :securable_type => securable_type }
    }}

    named_scope :blocked,   :conditions => { :block => true }
    named_scope :unblocked, :conditions => { :block => false }

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

    has_many(
      :principal_roles,
      :through => :principal_assignments,
      :source => :role
    )

    def self.granted_for(securable_type, principal_ids, permissions)
      with_type(securable_type).with_ids(
        Assignment.granting_for_principal(permissions, principal_ids).node_ids
      )
    end

    def self.blocked_for(securable_type)
      blocked.with_type(securable_type)
    end

  end
end
