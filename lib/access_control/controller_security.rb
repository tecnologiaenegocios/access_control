require 'access_control/principal'
require 'access_control/exceptions'

module AccessControl

  def self.controller_security_enabled?
    true
  end

  PublicActions = {}

  module ControllerSecurity

    module ClassMethods

      def action_public?(action)
        (PublicActions[self.name] || []).include?(action.to_sym)
      end

      def publish action
        (PublicActions[self.name] ||= []) << action.to_sym
      end

      def protect action, options, &block
        permission_name = options[:with]
        controller_action = [name, action.to_sym]
        context_designator = options[:context] || :current_context

        validate_context_designator!(context_designator)

        Registry.store(permission_name) do |permission|
          permission.controller_action << controller_action
          permission.context_designator[controller_action] = context_designator

          block.call(permission) if block
        end
      end

    private

      def validate_context_designator!(context_designator)
        return if context_designator.is_a?(Symbol)
        return if context_designator.is_a?(String)
        return if context_designator.is_a?(Proc)
        raise InvalidContextDesignator
      end

    end

    module InstanceMethods

      def self.included(base)
        base.extend(AccessControl::ControllerSecurity::ClassMethods)
        base.class_eval do
          alias_method_chain :process, :manager
        end
      end

      def process_with_manager(*args, &block)
        with_security do
          process_without_manager(*args, &block)
        end
      end

    private

      def verify_permissions
        return true if self.class.action_public?(params[:action])
        return true unless AccessControl.controller_security_enabled?

        query_key = [self.class.name, params[:action].to_sym]
        effective_permissions = Registry.query(:controller_action => query_key)
        raise(
          MissingPermissionDeclaration,
          "#{self.class.name}##{params[:action]} is missing permission "\
          "declaration"
        ) if effective_permissions.empty?

        effective_permissions.each do |permission|
          context_designator = permission.context_designator[query_key]
          context = fetch_context(context_designator)
          AccessControl.manager.can!(permission.name, context)
        end
      end

      def fetch_context(context_designator)
        validate_context(
          if context_designator.is_a?(Proc)
            context_designator.call(self)
          elsif context_designator.to_s =~ /^@.+/
            instance_variable_get(context_designator)
          else
            send(context_designator)
          end
        )
      end

      def validate_context(context)
        raise AccessControl::NoContextError unless context
        context
      end

      def current_context
        AccessControl.global_node
      end

      def with_security
        AccessControl.manager.use_anonymous!
        yield
      ensure
        AccessControl::Principal.clear_anonymous_cache
        AccessControl.no_manager
        AccessControl::Node.clear_global_cache
        PermissionInspector.clear_role_cache
      end

    end

  end

end

ActionController::Base.class_eval do
  include AccessControl::ControllerSecurity::InstanceMethods
end
