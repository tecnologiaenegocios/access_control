require 'access_control/active_record_just_after_callback'
require 'access_control/active_record_associator'
require 'access_control/declarations'
require 'access_control/node'
require 'access_control/persistency_protector'

module AccessControl
  module ActiveRecordSecurable
    def self.included(base)
      base.class_eval do
        include ActiveRecordJustAfterCallback
        extend ClassMethods
      end

      ActiveRecordAssociator.setup_association(:ac_node, base) do
        @__ac_node__ ||= Node.for_securable(self)
      end

      base.just_after_create do
        Role.default.assign_all_to(ac_node, AccessControl.manager.principals)
      end

      setup_persistency_protection_callbacks(base)
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
