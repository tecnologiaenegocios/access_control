require 'access_control/active_record_just_after_callback'
require 'access_control/active_record_associator'
require 'access_control/principal'

module AccessControl
  module ActiveRecordSubject

    def self.included(base)
      base.class_eval do
        include ActiveRecordJustAfterCallback

        ActiveRecordAssociator.setup_association(:ac_principal, base) do
          @__ac_principal__ ||= Principal.for_subject(self)
        end
      end
    end

  end
end
