require 'access_control/exceptions'

module AccessControl

  def self.controller_security_enabled?
    true
  end

  module ControllerSecurity

    module ClassMethods

      def protect action, options

        Registry.register(permissions = options[:with],
                          :controller => self.name,
                          :action => action.to_s)

        before_filter :only => action do |controller|
          permissions = [permissions] if !permissions.is_a?(Enumerable)
          permissions = Set.new(permissions)

          context = nil
          case options[:context]
          when Symbol, String
            if options[:context].to_s.starts_with?('@')
              context = controller.instance_variable_get(options[:context])
            else
              context = controller.send(options[:context])
            end
          when Proc
            context = options[:context].call(controller)
          else
            context = controller.send(:current_context)
          end

          raise ::AccessControl::NoContextError unless context

          manager = AccessControl.manager

          manager.can!(permissions, context) \
            if AccessControl.controller_security_enabled?
        end
      end

    end

    module InstanceMethods

      def self.included(base)
        base.extend(AccessControl::ControllerSecurity::ClassMethods)
        base.class_eval do
          alias_method_chain :process, :manager
        end
      end

      def process_with_manager(*args)
        with_security do
          process_without_manager(*args)
        end
      end

    private

      def current_context
        Contextualizer.new(self).context
      end

      def current_groups
        []
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
