require 'access_control/model_security/instance_methods'

module AccessControl

  def self.model_security_strict?
    true
  end

end

class ActiveRecord::Base

  include AccessControl::ModelSecurity::InstanceMethods

  before_validation :increment_validation_chain
  after_validation :decrement_validation_chain
  before_update :verify_update_permissions
  before_create :verify_create_permissions
  after_create :create_nodes
  after_update :update_parent_nodes
  after_save :update_child_nodes
  after_destroy :reparent_saved_referenced_children

end
