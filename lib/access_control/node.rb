require 'access_control/exceptions'
require 'access_control/inheritance'

module AccessControl
  class Node < ActiveRecord::Base

    set_table_name :ac_nodes

    belongs_to :securable, :polymorphic => true

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

    has_many(
      :assignments,
      :foreign_key => :node_id,
      :class_name => 'AccessControl::Assignment',
      :dependent => :destroy
    )

    accepts_nested_attributes_for :assignments, :allow_destroy => true

    has_many(
      :principal_roles,
      :through => :principal_assignments,
      :source => :role
    )

    def block= value
      AccessControl.manager.verify_access!(self, 'change_inheritance_blocking')
      self[:block] = value
    end

    def self.global
      Thread.current[:global_node_cache] ||= \
        find_by_securable_type_and_securable_id(
          global_securable_type,
          global_securable_id
        )
    end

    def self.global_id
      global.id
    end

    def self.global_securable_type
      'AccessControl::GlobalRecord'
    end

    def self.global_securable_id
      0
    end

    def self.create_global_node!
      clear_global_node_cache
      ActiveRecord::Base.connection.execute("
        INSERT INTO `ac_nodes` (`securable_type`, `securable_id`)
        VALUES ('#{global_securable_type}', #{global_securable_id})
      ")
    end

    def self.clear_global_node_cache
      Thread.current[:global_node_cache] = nil
    end

    def self.granted_for(securable_type, principal_ids, permissions,
                         conditions={})
      principal_ids = principal_ids.first if principal_ids.size == 1
      permissions = permissions.to_a
      permissions = permissions.first if permissions.size == 1
      find(
        :all,
        :joins => { :assignments => { :role => :security_policy_items } },
        :conditions => {
          :securable_type => securable_type,
          :'ac_assignments.principal_id' => principal_ids,
          :'ac_security_policy_items.permission' => permissions,
        }.merge(conditions)
      )
    end

    def self.blocked_for(securable_type)
      find_all_by_securable_type_and_block(securable_type, true)
    end

    def assignments_with_roles(filter_roles)
      assignments.with_roles(filter_roles)
    end

    def global?
      [securable_type, securable_id] == [
        self.class.global_securable_type,
        self.class.global_securable_id
      ]
    end

    def unblocked_ancestors
      Set.new([self]) | strict_unblocked_ancestors
    end

    def strict_unblocked_ancestors
      unblocked_parents.
        inject(Set.new([self.class.global])) do |ancestors, parent|
          ancestors | parent.unblocked_ancestors
        end
    end

    def ancestors
      Set.new([self]) | strict_ancestors
    end

    def strict_ancestors
      parents.inject(Set.new([self.class.global])) do |ancestors, parent|
        ancestors | parent.ancestors
      end
    end

    after_create :set_default_roles

  private

    def set_default_roles
      return unless AccessControl.config.default_roles_on_create
      AccessControl.manager.principal_ids.each do |principal_id|
        AccessControl.config.default_roles_on_create.each do |role|
          next unless role = Role.find_by_name(role)
          r = assignments.build(:role_id => role.id,
                                :principal_id => principal_id)
          r.skip_assignment_verification!
          r.save!
        end
      end
    end

    def parents
      if can_inherit?
        securable.inherits_permissions_from.inject(Set.new) do |parents, assoc|
          parents | SecurityContext.new(securable.send(assoc)).nodes
        end
      else
        Set.new
      end
    end

    def unblocked_parents
      block ? Set.new : parents
    end

    def can_inherit?
      securable.class.include?(Inheritance)
    end

  end

  class GlobalRecord
    include Singleton
    def ac_node
      AccessControl::Node.global
    end
    def self.find *args
      instance
    end
  end
end
