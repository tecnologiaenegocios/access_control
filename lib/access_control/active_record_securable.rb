require 'access_control/active_record_just_after_callback'
require 'access_control/active_record_associator'
require 'access_control/declarations'
require 'access_control/node'
require 'access_control/role_propagation'

module AccessControl
  module ActiveRecordSecurable

    class << self
      attr_writer :propagate_roles, :assign_default_roles

      def propagate_roles?
        @propagate_roles.nil?? true : @propagate_roles
      end

      def assign_default_roles?
        @assign_default_roles.nil?? true : @assign_default_roles
      end
    end


    def self.included(base)
      base.send(:include, ActiveRecordJustAfterCallback)

      ActiveRecordAssociator.setup_association(:ac_node, base) do
        @__ac_node__ ||= Node.for_securable(self)
      end

      if assign_default_roles?
        base.just_after_create do
          Role.assign_all(Role.default,
                          AccessControl.manager.principals, ac_node)
        end
      end

      if propagate_roles?
        setup_role_propagation_callbacks(base)
      end
    end

    def self.setup_role_propagation_callbacks(base)
      base.just_after_create do
        propagation = RolePropagation.new(ac_node)
        propagation.propagate!
      end
    end
  end
end
