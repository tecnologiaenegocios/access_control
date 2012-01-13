require 'access_control/active_record_just_after_callback'
require 'access_control/active_record_associator'
require 'access_control/declarations'
require 'access_control/node'
require 'access_control/role_propagation'

module AccessControl
  module ActiveRecordSecurable
    def self.included(base)
      base.send(:include, ActiveRecordJustAfterCallback)

      ActiveRecordAssociator.setup_association(:ac_node, base) do
        @__ac_node__ ||= Node.for_securable(self)
      end

      base.just_after_update do
        node_manager = NodeManager.new(ac_node)
        node_manager.refresh_parents
        node_manager.can_update!
      end

      base.just_after_create do
        node_manager = NodeManager.new(ac_node)
        node_manager.assign_default_roles
        node_manager.refresh_parents
      end
    end
  end
end
