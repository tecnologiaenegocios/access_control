require 'singleton'
require 'access_control/configuration'
require 'access_control/exceptions'
require 'access_control/registry'
require 'access_control/util'

module AccessControl
  module Macros
    def self.clear
      RequirementDeclaration.clear
    end

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
        RequirementDeclaration.items_for_class(self)[t].set(*permissions, &block)
      end

      define_method(:"add_#{t}_requirement") do |*permissions, &block|
        RequirementDeclaration.items_for_class(self)[t].add(*permissions, &block)
      end

      define_method(:"permissions_required_to_#{t}") do
        RequirementDeclaration.items_for_class(self)[t].get
      end
    end

    def requires_no_permissions!
      show_requires    nil
      list_requires    nil
      create_requires  nil
      update_requires  nil
      destroy_requires nil
    end

    def allocate
      RequirementDeclaration.check_missing_declarations!(self) unless include?(Singleton)
      super
    end

    unless AccessControl::Util.new_calls_allocate?
      def new(*args)
        RequirementDeclaration.check_missing_declarations!(self) unless include?(Singleton)
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
      AccessControl.unrestrict_method(self, method_name)
    end

    class Requirement
      def initialize(owner, *permission_names, &block)
        @owner = owner
        @names = Util.make_set_from_args(*permission_names)
        register(&block)
      end

      def get
        if @names.empty?
          inherited_permissions
        else
          AccessControl.registry.fetch_all(@names).to_set
        end
      end

      def null?
        get.empty? && superclass_declaration.declared.null?
      end

    private

      def register(&block)
        @names.each do |permission_name|
          AccessControl.registry.store(permission_name, &block)
        end
      end

      def inherited_permissions
        superclass_declaration.get
      end

      def superclass_declaration
        if @owner.superclass
          RequirementDeclaration.items_for_class(@owner.superclass)[type]
        else
          DefaultRequirementDeclaration.new(type)
        end
      end

      def type
        @owner.type
      end
    end

    class AddedRequirement < Requirement
      def get
        AccessControl.registry.fetch_all(@names).to_set
      end
    end

    class NullRequirement
      def get; Set.new; end
      def null?; true; end
    end

    class ConfigRequirement
      def initialize(type)
        @type = type
      end

      def get
        config.send(:"permissions_required_to_#{@type}")
      end

      def null?
        false
      end

    private

      def config
        AccessControl.config
      end
    end

    class RequirementDeclaration
      class << self
        def items_for_class(klass)
          requirements[klass.name] ||= Hash.new do |hash, type|
            hash[type] = new(klass, type)
          end
        end

        def check_missing_declarations!(klass)
          return if already_checked_class_object?(klass)
          [:show, :list, :create, :update, :destroy].each do |type|
            req = items_for_class(klass)[type]
            if req.get.empty? && !req.declared.null?
              raise MissingPermissionDeclaration,
                    "expected to have declaration for #{type} in model "\
                    "#{klass.name}"
            end
          end
          mark_class_object_as_checked(klass)
        end

        def clear
          requirements.clear
        end

      private

        INST_VAR_NAME = :@__AccessControl_checked_missing_declarations__

        def requirements
          @requirements ||= {}
        end

        def already_checked_class_object?(klass)
          klass.instance_variable_get(INST_VAR_NAME)
        end

        def mark_class_object_as_checked(klass)
          klass.instance_variable_set(INST_VAR_NAME, true)
        end
      end

      attr_reader :type
      def initialize(owner, type)
        @owner = owner
        @type = type
      end

      def set(*permissions, &block)
        if permissions == [nil]
          @declared = NullRequirement.new
        else
          @declared = Requirement.new(self, *permissions, &block)
        end
      end

      def add(*permissions, &block)
        @added = AddedRequirement.new(self, *permissions, &block)
      end

      def get
        declared.get | added.get
      end

      def declared
        @declared ||= Requirement.new(self, Set.new)
      end

      def added
        @added ||= AddedRequirement.new(self, Set.new)
      end

      def superclass
        @owner.superclass
      end
    end

    class DefaultRequirementDeclaration
      attr_reader :declared
      def initialize(type)
        @declared ||= ConfigRequirement.new(type)
      end

      def get
        declared.get
      end
    end
  end
end
