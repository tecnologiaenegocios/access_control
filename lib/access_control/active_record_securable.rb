require 'access_control/active_record_associator'
require 'access_control/declarations'
require 'access_control/node'
require 'access_control/persistency_protector'

module AccessControl
  module ActiveRecordSecurable

    def self.included(base)
      base.send(:include, ActiveRecordAssociator)
      base.send(:include, Declarations)
      base.class_eval do
        associate_with_access_control(:ac_node, Node.name, :securable)
      end
      base.extend(ClassMethods)
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

    def destroy
      PersistencyProtector.verify_detachment!(self)
      super
    end

  private

    def create_without_callbacks
      PersistencyProtector.verify_attachment!(self)
      super
    end

    def update_without_callbacks(*args)
      PersistencyProtector.verify_detachment!(self)
      PersistencyProtector.verify_attachment!(self)
      PersistencyProtector.verify_update!(self)
      super
    end
  end
end
