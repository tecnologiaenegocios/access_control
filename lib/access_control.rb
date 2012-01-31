require 'rubygems'
require 'access_control/db'
require 'access_control/behavior'
require 'action_controller'

# Models
require 'access_control/assignment'
require 'access_control/assignment/persistent'
require 'access_control/node'
require 'access_control/node/inheritance_manager'
require 'access_control/node/persistent'
require 'access_control/principal'
require 'access_control/role'
require 'access_control/role/persistent'
require 'access_control/security_policy_item'

require 'access_control/util'
require 'access_control/assignment_combination'
require 'access_control/configuration'
require 'access_control/version'
require 'access_control/exceptions'
require 'access_control/controller_security'
require 'access_control/manager'
require 'access_control/registry'
require 'access_control/securable'
require 'access_control/active_record_subject'

module AccessControl
  LIB_PATH = File.dirname(__FILE__)
end
