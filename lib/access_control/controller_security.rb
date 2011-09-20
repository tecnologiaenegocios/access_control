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
          :__ac_controller__ => self.name,
          :__ac_action__     => action.to_sym,
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
        default_metadata = {
          :__ac_controller__ => self.class.name,
          :__ac_action__     => params[:action].to_sym
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
            m[:__ac_controller__] == default_metadata[:__ac_controller__] &&
              m[:__ac_action__]   == default_metadata[:__ac_action__]
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
        Contextualizer.new(self).context
      end

      def with_security
        AccessControl.manager.use_anonymous!
        yield
      ensure
        AccessControl::Principal.clear_anonymous_principal_cache
        AccessControl.no_manager
        AccessControl::Node.clear_global_node_cache
      end

      class Contextualizer

        RESOURCE_ACTIONS = %w(show destroy edit update)
        COLLECTION_ACTIONS = %w(index new create)

        attr_reader :controller

        def initialize controller
          @controller = controller
        end

        def context
          fetch_candidate_resource || AccessControl::Node.global
        end

      private

        def fetch_candidate_resource
          if resource_action?
            fetch_resource
          elsif collection_action?
            fetch_parent
          end
        end

        def resource_action?
          RESOURCE_ACTIONS.include?(params[:action])
        end

        def params
          controller.send(:params)
        end

        def fetch_resource
          controller.instance_variable_get(expected_resource_var_name)
        end

        def expected_resource_var_name
          '@' + controller_path.gsub('/', '_').singularize
        end

        def controller_path
          controller.send(:controller_path)
        end

        def collection_action?
          COLLECTION_ACTIONS.include?(params[:action])
        end

        def fetch_parent
          var = expected_parent_var_name
          var && controller.instance_variable_get(var)
        end

        def expected_parent_var_name
          return unless route = ActionController::Routing::Routes.routes.select do |r|
            r.matches_controller_and_action?(controller_path, params[:action]) &&
              r.defaults[:controller] == controller_path
          end.first
          return unless segment = route.segments.reverse.detect do |s|
            ActionController::Routing::DynamicSegment === s && !s.optional?
          end
          '@' + segment.key.to_s.gsub(/_id$/, '')
        end

      end

    end

  end

end

ActionController::Base.class_eval do
  include AccessControl::ControllerSecurity::InstanceMethods
end
