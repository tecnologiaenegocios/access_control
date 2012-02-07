require 'access_control/active_record_securable'
require 'access_control/macros'
require 'access_control/inheritance'
require 'access_control/method_protection'
require 'access_control/restriction'

module AccessControl
  module Securable
    def self.included(base)
      base.send(:extend, Macros)
      base.send(:include, MethodProtection)
      if base < ActiveRecord::Base
        base.send(:include, ActiveRecordSecurable)
        base.send(:include, Inheritance)
        base.send(:include, Restriction)
      end
    end
  end
end
