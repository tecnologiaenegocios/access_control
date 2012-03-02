require 'singleton'
require 'access_control/configuration'
require 'access_control/exceptions'
require 'access_control/registry'
require 'access_control/util'

module AccessControl
  def self.macro_requirements
    @macro_requirements ||= {}
  end

  module Macros

    # def show_requires
    # def list_requires
    # def create_requires
    # def update_requires
    # def destroy_requires

    # def add_show_requirement
    # def add_list_requirement
    # def add_create_requirement
    # def add_update_requirement
    # def add_destroy_requirement

    # def permissions_required_to_show
    # def permissions_required_to_list
    # def permissions_required_to_create
    # def permissions_required_to_update
    # def permissions_required_to_destroy

    [:show, :list, :create, :update, :destroy].each do |t|

      define_method(:"#{t}_requires") do |*permissions, &block|
        permission_requirement(t).set(*permissions, &block)
      end

      define_method(:"add_#{t}_requirement") do |*permissions, &block|
        permission_requirement(t).add(*permissions, &block)
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

    def define_unrestricted_method(name, &block)
      define_method(name) do |*args, &argument_block|
        AccessControl.manager.trust do
          block.call(*args, &argument_block)
        end
      end
    end

    def unrestrict_method(method_name)
      method_name = method_name.to_sym

      class_eval do
        alias_method :"unstrusted_#{method_name}", method_name

        define_method(method_name) do |*args, &block|
          AccessControl.manager.trust do
            send(:"unstrusted_#{method_name}", *args, &block)
          end
        end
      end
    end

  private

    def permission_requirement(type)
      (AccessControl.macro_requirements[self.name] ||= {})[type] ||=
        Requirement.new(self, type)
    end

    def check_missing_declarations!
      return if @checked_missing_declarations
      [:show, :list, :create, :update, :destroy].each do |t|
        req = permission_requirement(t)
        if req.get.empty? && !req.declared_no_permissions?
          raise MissingPermissionDeclaration,
                "expected to have declaration for #{t} in model #{name}"
        end
      end
      @checked_missing_declarations = true
    end

    class Requirement

      def initialize(owner, type)
        @owner = owner
        @type = type
        @declared_no_permissions = false
        @declared = Set.new
        @added = Set.new
      end

      def set(*permissions, &block)
        if permissions == [nil]
          declared_no_permissions!
          permissions = Set.new
        end
        @declared = Util.make_set_from_args(*permissions)
        register(@declared, &block)
      end

      def add(*permissions, &block)
        @added = Util.make_set_from_args(*permissions)
        register(@added, &block)
      end

      def get
        AccessControl.registry.fetch_all(get_names).to_set
      end

      def declared_no_permissions?
        !!@declared_no_permissions
      end

    private

      def get_names
        return Set.new if declared_no_permissions?
        return @declared | @added if @declared.any?
        get_names_from_superclass_or_config | @added
      end

      def declared_no_permissions!
        @declared_no_permissions = true
      end

      def register(permission_names, &block)
        permission_names.each do |permission_name|
          AccessControl.registry.store(permission_name, &block)
        end
      end

      def get_names_from_superclass_or_config
        get_from_superclass_or_config.map(&:name).to_set
      end

      def get_from_superclass_or_config
        if superclass.respond_to?(:"permissions_required_to_#{@type}")
          superclass.send(:"permissions_required_to_#{@type}") rescue Set.new
        else
          config.send(:"permissions_required_to_#{@type}")
        end
      end

      def superclass
        @owner.superclass
      end

      def config
        AccessControl.config
      end

    end

  end
end
