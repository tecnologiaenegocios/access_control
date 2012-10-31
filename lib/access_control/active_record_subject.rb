require 'access_control/active_record_association'
require 'access_control/principal'

module AccessControl
  module ActiveRecordSubject
    def self.included(base)
      ActiveRecordAssociation.setup_association(:ac_principal, :subject_id,
                                                base) do
        @__ac_principal__ ||= Principal.for_subject(self)
      end
    end
  end
end
