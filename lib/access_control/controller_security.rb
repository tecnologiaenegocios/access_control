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

      def protect action, options
        metadata = (options[:data] || {}).merge(
          :__ac_controller_action__ => [self.name, action.to_sym],
          :__ac_context__    => options[:context] || :current_context
        )
        Registry.register(options[:with], metadata)
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
        metadata_key = :__ac_controller_action__
        default_metadata = {
          metadata_key => [self.class.name, params[:action].to_sym]
        }
        effective_permissions = Registry.query(default_metadata)

        raise(
          MissingPermissionDeclaration,
          "#{self.class.name}##{params[:action]} is missing permission "\
          "declaration"
        ) if effective_permissions.empty?

        all_permissions = Registry.all_with_metadata
        effective_permissions.each do |permission|
          # We are sure to detect the right metadata because we queried for it
          # above.
          metadata = all_permissions[permission].detect do |m|
            m[metadata_key] == default_metadata[metadata_key]
          end
          AccessControl.manager.can!(permission,
                                     fetch_context(metadata[:__ac_context__]))
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
        AccessControl::Principal.clear_anonymous_principal_cache
        AccessControl.no_manager
        AccessControl.clear_global_node_cache
      end

    end

  end

end

ActionController::Base.class_eval do
  include AccessControl::ControllerSecurity::InstanceMethods
end
