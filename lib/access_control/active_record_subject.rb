require 'access_control/active_record_associator'
require 'access_control/principal'

module AccessControl
  module ActiveRecordSubject

    def self.included(base)
      base.send(:include, ActiveRecordAssociator)
      base.class_eval do
        associate_with_access_control(:ac_principal, Principal.name, :subject)
      end
    end

  end
end
