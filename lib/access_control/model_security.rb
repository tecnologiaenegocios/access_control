require 'access_control/model_security/instance_methods'

class ActiveRecord::Base

  include AccessControl::ModelSecurity::InstanceMethods

  before_validation :disable_query_restriction
  after_validation :re_enable_query_restriction
  before_update :verify_update_permissions
  before_create :verify_create_permissions
  before_destroy :verify_destroy_permissions
  after_create :create_nodes
  after_update :update_parent_nodes
  after_save :update_child_nodes
  after_destroy :reparent_saved_referenced_children

end
