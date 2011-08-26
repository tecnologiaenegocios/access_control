require 'access_control/exceptions'
require 'access_control/permission_registry'
require 'access_control/util'

module AccessControl
  module Declarations

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods

      [:view, :query, :create, :update, :destroy].each do |t|

        define_method(:"#{t}_requires") do |*permissions|
          permission_requirement(t).set(*permissions)
        end

        define_method(:"add_#{t}_requirement") do |*permissions|
          permission_requirement(t).add(*permissions)
        end

        define_method(:"permissions_required_to_#{t}") do
          permission_requirement(t).get
        end

      end

    private

      def permission_requirement(type)
        (@permission_requirements ||= {})[type] ||= Requirement.new(self, type)
      end

      class Requirement

        def initialize(owner, type)
          @owner = owner
          @type = type
          @declared_no_permissions = false
          @declared = Set.new
          @added = Set.new
        end

        def set(*permissions)
          if permissions == [:none]
            declared_no_permissions!
            permissions = Set.new
          end
          register(*permissions)
          @declared = Util.make_set_from_args(*permissions)
        end

        def add(*permissions)
          register(*permissions)
          @added = Util.make_set_from_args(*permissions)
        end

        def get
          return Set.new if declared_no_permissions?
          return @declared | @added if @declared.any?
          assert_and_return(get_from_superclass_or_config | @added)
        end

      private

        def declared_no_permissions?
          !!@declared_no_permissions
        end

        def declared_no_permissions!
          @declared_no_permissions = true
        end

        def register(*permissions)
          args_to_register = permissions.dup + [{
            :action => @type.to_s,
            :model => @owner.name
          }]
          PermissionRegistry.register(*args_to_register)
        end

        def get_from_superclass_or_config
          if superclass.respond_to?(:"permissions_required_to_#{@type}")
            superclass.send(:"permissions_required_to_#{@type}") rescue Set.new
          else
            config.send(:"default_#{@type}_permissions")
          end
        end

        def superclass
          @owner.superclass
        end

        def config
          AccessControl.config
        end

        def assert_and_return(values)
          raise AccessControl::MissingPermissionDeclaration if values.empty?
          values
        end

      end

    end

  end
end
