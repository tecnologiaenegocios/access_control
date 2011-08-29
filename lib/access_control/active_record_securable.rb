require 'access_control/active_record_associator'
require 'access_control/declarations'
require 'access_control/node'

module AccessControl
  module ActiveRecordSecurable

    def self.included(base)
      base.send(:include, ActiveRecordAssociator)
      base.send(:include, Declarations)
      base.class_eval do
        associate_with_access_control(:ac_node, Node.name, :securable)
      end
    end

  private

    def create_without_callbacks
      super
      verify_create_permissions
    end

    def update(*args)
      verify_update_permissions
      super
    end

    def destroy
      verify_destroy_permissions
      super
    end

    def verify_default_permissions?(type)
      self.class.send(:"permissions_required_to_#{type}").any?
    end

    def verify_create_permissions
      return unless verify_default_permissions?('create')
      AccessControl.manager.verify_access!(
        self, self.class.permissions_required_to_create
      )
    end

    def verify_update_permissions
      return unless verify_default_permissions?('update')
      AccessControl.manager.verify_access!(
        self, self.class.permissions_required_to_update
      )
    end

    def verify_destroy_permissions
      return unless verify_default_permissions?('destroy')
      AccessControl.manager.verify_access!(
        self, self.class.permissions_required_to_destroy
      )
    end

  end
end
