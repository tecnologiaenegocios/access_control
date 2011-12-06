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
    end

    def destroy
      PersistencyProtector.new(self).verify!('destroy')
      super
    end

  private

    def create_without_callbacks
      super
      PersistencyProtector.new(self).verify!('create')
    end

    def update(*args)
      PersistencyProtector.new(self).verify!('update')
      super
    end
  end
end
