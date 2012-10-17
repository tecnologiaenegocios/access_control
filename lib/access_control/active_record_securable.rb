require 'access_control/active_record_just_after_callback'
require 'access_control/active_record_associator'
require 'access_control/node'

module AccessControl
  module ActiveRecordSecurable
    def self.included(base)
      base.send(:include, ActiveRecordJustAfterCallback)

      ActiveRecordAssociator.setup_association(:ac_node, :securable_id,
                                               base) do
        @__ac_node__ ||= Node.for_securable(self)
      end
    end
  end
end
