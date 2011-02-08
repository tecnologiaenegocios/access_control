module AccessControl

  module ControllerSecurity

    module ClassMethods

      # Example:
      #
      # class PeopleController < ApplicationController
      #   ...
      #   protect :edit, :with => 'edit_person'
      #   ...
      # end
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

      # Put this before any protect call in application controller:
      # class ApplicationController < ActionController::Base
      #   ...
      #   around_filter :run_with_security_manager
      #   ...
      #   protect ...
      #   ...
      # end
      #
      # class PeopleController < ApplicationController
      #   protect :create, :with => 'create_person'
      #   ...
      # end
      #
      # Be sure that your controller has a `current_user` instance method that
      # returns the current user or nil if there's no user authenticated, and a
      # `current_groups` method that returns an array of the user's groups (or
      # an empty array).
      def run_with_security_manager
        AccessControl.set_security_manager(self)
        yield
      ensure
        AccessControl.no_security_manager
      end

      # Override this method to return the security context for the action
      # being executed.  Returning nil tells the security system that there's
      # no context defined, which will raise an error at the first call to a
      # protected action.
      #
      # You can turn this method protected or private if you wish.
      def current_security_context
      end

    end

  end

end

ActionController::Base.class_eval do
  include AccessControl::ControllerSecurity::InstanceMethods
  around_filter :run_with_security_manager
end
