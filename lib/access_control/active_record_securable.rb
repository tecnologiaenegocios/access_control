require 'access_control/active_record_just_after_callback'
require 'access_control/active_record_associator'
require 'access_control/node'
require 'access_control/node_manager'

module AccessControl
  module ActiveRecordSecurable
    def self.included(base)
      base.send(:include, ActiveRecordJustAfterCallback)

      ActiveRecordAssociator.setup_association(:ac_node, base) do
        @__ac_node__ ||= Node.for_securable(self)
      end

      base.just_after_update do
        ac_node.refresh_parents
        ac_node.can_update!
      end

      base.just_after_create do
        Role.assign_default_at(ac_node)
        ac_node.refresh_parents
      end
    end
  end
end
