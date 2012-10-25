require 'access_control/registry'
require 'access_control/util'

module AccessControl
  module MethodProtection

    def self.included(base)
      base.extend(ClassMethods)
    end

    def self.guard(instance)
      Protector.new(instance).guard
    end

    def self.check(instance, method_name)
      permissions = permissions_for(instance.class, method_name)
      AccessControl.manager.can!(permissions, instance)
    end

    def self.permissions_for(klass, method_name)
      key = [[klass.name, method_name.to_sym]]
      permissions = AccessControl.registry.query(:ac_methods => key)
      if permissions.empty? && klass.superclass
        permissions_for(klass.superclass, method_name)
      else
        permissions
      end
    end

    module ClassMethods
      def protect(method_name, options, &block)
        permission_name = options[:with]
        class_name      = self.name
        Registry.store(permission_name) do |permission|
          permission.ac_methods << [class_name, method_name.to_sym]
          permission.ac_classes << class_name
          yield(permission) if block_given?
        end
      end

      def allocate
        super.tap { |instance| MethodProtection.guard(instance) }
      end

      unless AccessControl::Util.new_calls_allocate?
        def new(*args, &block)
          if !private_method_defined?(:__method_protection_initialize__)
            if private_method_defined?(:initialize)
              define_method(:__method_protection_initialize__) do |*args, &block|
                MethodProtection.guard(self)
                __method_protection_original_initialize__(*args, &block)
              end
              private :__method_protection_initialize__
              alias_method :__method_protection_original_initialize__, :initialize
              alias_method :initialize, :__method_protection_initialize__
              super
            else
              super.tap { |instance| MethodProtection.guard(instance) }
            end
          else
            super
          end
        end
      end
    end

    class Protector
      def initialize(instance)
        @instance   = instance
        @klass      = instance.class
        @class_name = @klass.name
      end

      def guard
        instance.extend(extension_module)
      end

    private

      attr_reader :instance, :klass, :class_name

      def extension_module
        cached_in_class_object(:extension_module) do
          Module.new.tap do |mod|
            mod.module_exec(restricted_methods) do |methods|
              methods.each do |method_name|
                module_eval(<<-METHOD, __FILE__, __LINE__ + 1)
                  def #{method_name}(*args, &block)
                    AccessControl::MethodProtection.check(self, :#{method_name})
                    super
                  end
                METHOD
              end
            end
          end
        end
      end

      def restricted_methods
        klasses = class_and_superclasses_of(klass)
        class_names = klasses.map(&:name)
        Registry.query(:ac_classes => class_names).flat_map do |p|
          p.ac_methods.select { |k, m| class_names.include?(k) }.map do |k, m|
            m
          end
        end.uniq
      end

      def class_and_superclasses_of(klass)
        return [] unless klass
        [klass] + class_and_superclasses_of(klass.superclass)
      end

      def cached_in_class_object(key, &block)
        Cache.new(klass).fetch(key, &block)
      end
    end

    class Cache
      def initialize(klass)
        @klass = klass
      end

      def fetch(key, &block)
        cache[key] ||= block.call
      end

    private

      def cache
        @klass.instance_eval { @__method_protection_cache__ ||= {} }
      end
    end
  end
end
