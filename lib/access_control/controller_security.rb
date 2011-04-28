require 'access_control/exceptions'

module AccessControl

  def self.controller_security_enabled?
    true
  end

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
            if options[:context].to_s.starts_with?('@')
              context = controller.instance_variable_get(options[:context])
            else
              context = controller.send(options[:context])
            end
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

          manager.verify_access!(context, permissions) \
            if AccessControl.controller_security_enabled?
        end
      end

    end

    module InstanceMethods

      RESOURCE_ACTIONS = %w(show destroy edit update)
      COLLECTION_ACTIONS = %w(index new create)

      def self.included(base)
        base.extend(AccessControl::ControllerSecurity::ClassMethods)
        base.class_eval do
          alias_method_chain :process, :security_manager
        end
      end

      # Convenience method.
      def security_manager
        AccessControl.security_manager
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
          Thread.current[:validation_chain_depth] = nil
        end

        def _resource_action?
          RESOURCE_ACTIONS.include?(params[:action])
        end

        def _collection_action?
          COLLECTION_ACTIONS.include?(params[:action])
        end

        def _expected_resource_var_name
          '@' + controller_path.gsub('/', '_').singularize
        end

        def _expected_parent_var_name
          return unless route = ActionController::Routing::Routes.routes.select do |r|
            r.matches_controller_and_action?(controller_path, params[:action]) &&
              r.defaults[:controller] == controller_path
          end.first
          return unless segment = route.segments.reverse.detect do |s|
            ActionController::Routing::DynamicSegment === s && !s.optional?
          end
          '@' + segment.key.to_s.gsub(/_id$/, '')
        end

        def _fetch_resource
          instance_variable_get(_expected_resource_var_name)
        end

        def _fetch_parent
          var = _expected_parent_var_name
          var && instance_variable_get(var)
        end

        def _fetch_candidate_resource
          if _resource_action?
            _fetch_resource
          elsif _collection_action?
            _fetch_parent
          end
        end

        def current_security_context
          (resource = _fetch_candidate_resource) ?
            resource.ac_node :
            AccessControl::Node.global
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
