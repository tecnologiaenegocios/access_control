require 'rubygems'
require 'active_record'
require 'action_controller'
require 'access_control/configuration'
require 'access_control/version'
require 'access_control/exceptions'
require 'access_control/controller_security'
require 'access_control/model'
require 'access_control/model_security'
require 'access_control/security_manager'
require 'access_control/security_proxy'

module AccessControl
  LIB_PATH = File.dirname(__FILE__)
end
