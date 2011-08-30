require 'rubygems'
require 'active_record'
require 'action_controller'

# Models
require 'access_control/assignment'
require 'access_control/node'
require 'access_control/principal'
require 'access_control/role'
require 'access_control/security_policy_item'

require 'access_control/util'
require 'access_control/configuration'
require 'access_control/version'
require 'access_control/exceptions'
require 'access_control/controller_security'
require 'access_control/association_security'
require 'access_control/manager'
require 'access_control/context'
require 'access_control/permission_registry'
require 'access_control/securable'
require 'access_control/active_record_subject'

module AccessControl

  MANAGER_THREAD_KEY = :ac_manager

  def self.manager
    Thread.current[MANAGER_THREAD_KEY] ||= Manager.new
  end

  def self.no_manager
    Thread.current[MANAGER_THREAD_KEY] = nil
  end

  LIB_PATH = File.dirname(__FILE__)
end
