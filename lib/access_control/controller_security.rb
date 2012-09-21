require 'access_control/principal'
require 'access_control/exceptions'
require 'access_control/registry'

module AccessControl
  def self.controller_security_enabled?
    true
  end

  module ControllerSecurity
    def self.protected_actions
      @protected_actions ||= Hash.new { |h, k| h[k] = Set.new }
    end

    def self.published_actions
      @published_actions ||= Hash.new { |h, k| h[k] = Set.new }
    end

    def self.clear
      published_actions.clear
      protected_actions.clear
    end

    module ClassMethods

      def action_published?(action)
        ControllerSecurity.published_actions[name].include?(action.to_sym)
      end

      def action_protected?(action)
        ControllerSecurity.protected_actions[name].include?(action.to_sym)
      end

      def publish action
        ControllerSecurity.published_actions[name] << action.to_sym
      end

      def unpublish action
        ControllerSecurity.published_actions[name].delete(action.to_sym)
      end

      def protect action, options, &block
        ControllerSecurity.protected_actions[name] << action.to_sym

        permission_name = options[:with]
        ac_method = [name, action.to_sym]
        context_designator = options[:context] || :current_context

        validate_context_designator!(context_designator)

        AccessControl.registry.store(permission_name) do |permission|
          permission.ac_methods << ac_method
          permission.context_designator[ac_method] = context_designator

          block.call(permission) if block
        end
      end

      def unprotect action
        ControllerSecurity.protected_actions[name].delete(action.to_sym)
        registry  = AccessControl.registry
        query_key = [name, action.to_sym]
        registry.query(:ac_methods => [query_key]).each do |permission|
          registry.unstore(permission.name)
        end
      end

    private

      def validate_context_designator!(context_designator)
        return if context_designator.is_a?(Symbol)
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
        return true if self.class.action_published?(params[:action])
        return true unless AccessControl.controller_security_enabled?

        query_key = [self.class.name, params[:action].to_sym]
        description = "#{self.class.name}##{params[:action]}"

        permissions = AccessControl.registry.query(:ac_methods => [query_key])
        raise(
          MissingPermissionDeclaration,
          "#{description} is missing permission declaration"
        ) if permissions.empty?

        cached_contexts = {}
        permissions.each do |permission|
          context_designator = permission.context_designator[query_key]
          cached_contexts[context_designator] ||=
            fetch_context(context_designator)
          context = cached_contexts[context_designator]

          AccessControl.manager.can!(permission, context)
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
