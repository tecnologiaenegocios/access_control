require 'access_control/exceptions'

module AccessControl

  module ControllerSecurity

    module ClassMethods

      def protect action, options

        PermissionRegistry.register(
          permissions = options[:with],
          :controller => self.name,
          :action => action.to_s
        )

        before_filter :only => action do |controller|
          permissions = [permissions] if !permissions.is_a?(Enumerable)
          permissions = Set.new(permissions)

          context = nil
          case options[:context]
          when Symbol, String
            context = controller.send(options[:context])
          when Proc
            context = options[:context].call(controller)
          else
            context = controller.send(:current_security_context)
          end

          raise ::AccessControl::NoSecurityContextError unless context

          manager = AccessControl.security_manager

          if options[:when_instantiating]
            model = options[:when_instantiating]
            model = model.to_s.constantize if !model.is_a?(Class)
            model.set_temporary_instantiation_requirement(context, permissions)
            next
          end

          manager.verify_access!(context, permissions)
        end
      end

    end

    module InstanceMethods

      def self.included(base)
        base.extend(AccessControl::ControllerSecurity::ClassMethods)
        base.class_eval do
          alias_method_chain :process, :security_manager
        end
      end

      def process_with_security_manager(*args)
        run_with_security_manager do
          process_without_security_manager(*args)
        end
      end

      private

        def run_with_security_manager
          AccessControl.set_security_manager(self)
          yield
        ensure
          AccessControl.no_security_manager
          AccessControl::Node.clear_global_node_cache
          ActiveRecord::Base.drop_all_temporary_instantiation_requirements!
        end

        def current_security_context
          if AccessControl::Node.global
            return AccessControl::Node.global
          end
          nil
        end

        def current_groups
          []
        end

    end

  end

end

ActionController::Base.class_eval do
  include AccessControl::ControllerSecurity::InstanceMethods
end
