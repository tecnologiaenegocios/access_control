require 'access_control/active_record_just_after_callback'
require 'access_control/active_record_associator'
require 'access_control/declarations'
require 'access_control/node'
require 'access_control/persistency_protector'
require 'access_control/role_propagation'

module AccessControl
  module ActiveRecordSecurable

    class << self
      attr_writer :propagate_roles, :assign_default_roles, :protect_persistency,
                  :track_parents

      def propagate_roles?
        @propagate_roles.nil?? true : @propagate_roles
      end

      def assign_default_roles?
        @assign_default_roles.nil?? true : @assign_default_roles
      end

      def protect_persistency?
        @protect_persistency.nil?? true : @protect_persistency
      end

      def track_parents?
        @track_parents.nil?? true : @track_parents
      end
    end


    def self.included(base)
      base.send(:include, ActiveRecordJustAfterCallback)

      ActiveRecordAssociator.setup_association(:ac_node, base) do
        @__ac_node__ ||= Node.for_securable(self)
      end

      if track_parents?
        base.extend(ClassMethods)
      end

      if assign_default_roles?
        base.just_after_create do
          Role.assign_all(Role.default,
                          AccessControl.manager.principals, ac_node)
        end
      end

      if protect_persistency?
        setup_persistency_protection_callbacks(base)
      end

      if propagate_roles?
        setup_role_propagation_callbacks(base)
      end
    end

    def self.setup_persistency_protection_callbacks(base)
      base.just_after_create do
        PersistencyProtector.verify_attachment!(self)
      end

      base.just_after_update do
        PersistencyProtector.verify_attachment!(self)
        PersistencyProtector.verify_detachment!(self)
        PersistencyProtector.verify_update!(self)
      end

      base.just_after_destroy do
        PersistencyProtector.verify_detachment!(self)
      end
    end

    def self.setup_role_propagation_callbacks(base)
      base.just_after_create do
        propagation = RolePropagation.new(ac_node)
        propagation.propagate!
      end
    end

    module ClassMethods
      def instantiate(*args)
        result = super
        PersistencyProtector.track_parents(result)
        result
      end

      def new(*args)
        result = super
        PersistencyProtector.track_parents(result)
        result
      end
    end
  end
end
