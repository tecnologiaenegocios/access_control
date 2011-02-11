module AccessControl

  module ControllerSecurity

    module ClassMethods

      def protect action, options
        before_filter :only => action do |controller|
          permissions = options[:with]
          permissions = [permissions] if !permissions.is_a?(Enumerable)
          permissions = Set.new(permissions)
          context = controller.send(:current_security_context)
          raise ::AccessControl::NoSecurityContextError unless context
          AccessControl.get_security_manager.verify_access!(
            context, permissions
          )
        end
      end

    end

    module InstanceMethods

      def self.included(base)
        base.extend(AccessControl::ControllerSecurity::ClassMethods)
      end

      def run_with_security_manager
        AccessControl.set_security_manager(self)
        yield
      ensure
        AccessControl.no_security_manager
      end

      def current_security_context
      end

    end

  end

end

ActionController::Base.class_eval do
  include AccessControl::ControllerSecurity::InstanceMethods
  around_filter :run_with_security_manager
end
