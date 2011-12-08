require 'access_control/configuration'
require 'access_control/exceptions'
require 'access_control/registry'
require 'access_control/util'

module AccessControl
  module Declarations

    def self.included(base)
      base.extend(ClassMethods)
    end

    Requirements = {}

    module ClassMethods

      [:show, :index, :create, :update, :destroy].each do |t|

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

      def allocate
        check_missing_declarations! unless include?(Singleton)
        super
      end

      unless AccessControl::Util.new_calls_allocate?
        def new(*args)
          check_missing_declarations! unless include?(Singleton)
          super
        end
      end

    private

      def permission_requirement(type)
        (Requirements[self.name] ||= {})[type] ||= Requirement.new(self, type)
      end

      def check_missing_declarations!
        return if @checked_missing_declarations
        [:show, :index, :create, :update, :destroy].each do |t|
          if permission_requirement(t).get.empty? &&
             !permission_requirement(t).declared_no_permissions?
            raise MissingPermissionDeclaration,
                  "expected to have declaration for #{t} in model #{name}"
          end
        end
        @checked_missing_declarations = true
      end

      class Requirement

        def initialize(owner, type)
          @owner_name = owner.name
          @type = type
          @declared_no_permissions = false
          @declared = Set.new
          @added = Set.new
        end

        def set(*permissions)
          metadata = permissions.extract_options!
          if permissions == [nil]
            declared_no_permissions!
            permissions = Set.new
          else
            register(*(permissions + [metadata]))
          end
          @declared = Util.make_set_from_args(*permissions)
        end

        def add(*permissions)
          metadata = permissions.extract_options!
          register(*(permissions + [metadata]))
          @added = Util.make_set_from_args(*permissions)
        end

        def get
          return Set.new if declared_no_permissions?
          return @declared | @added if @declared.any?
          get_from_superclass_or_config | @added
        end

        def declared_no_permissions?
          !!@declared_no_permissions
        end

      private

        def declared_no_permissions!
          @declared_no_permissions = true
        end

        def register(*permissions)
          Registry.register(*permissions.dup)
        end

        def get_from_superclass_or_config
          if superclass.respond_to?(:"permissions_required_to_#{@type}")
            superclass.send(:"permissions_required_to_#{@type}") rescue Set.new
          else
            config.send(:"default_#{@type}_permissions")
          end
        end

        def superclass
          @owner_name.constantize.superclass
        end

        def config
          AccessControl.config
        end

      end

    end

  end
end
