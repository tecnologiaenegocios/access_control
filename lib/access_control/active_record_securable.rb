require 'access_control/active_record_associator'
require 'access_control/node'

module AccessControl
  module ActiveRecordSecurable

    def self.included(base)
      base.send(:include, ActiveRecordAssociator)
      base.class_eval do
        associate_with_access_control(:ac_node, Node.name, :securable)
      end
    end

  end
end
