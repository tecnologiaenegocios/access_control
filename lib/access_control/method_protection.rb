require 'access_control/registry_factory'
require 'access_control/util'

module AccessControl
  module MethodProtection

    def self.included(base)
      base.extend(ClassMethods)
    end

    class Protector

      def initialize(klass)
        @class = klass
        @class_name = klass.name
      end

      def get_permissions_for(method_name)
        Registry.query(
          :__ac_class__  => @class_name,
          :__ac_method__ => method_name.to_sym
        )
      end

      def set_permissions_for(method_name, options)
        Registry.register(options[:with], (options[:data] || {}).merge(
          :__ac_class__  => @class_name,
          :__ac_method__ => method_name.to_sym
        ))
      end

      def protect_methods
        return if method_protection_complete?
        defined_restricted_methods.each do |method_name|
          protect_method(method_name)
        end
        class << @class
          def method_added(method_name)
            Protector.new(self).protect_method(method_name)
            super
          end
        end
        mark_method_protection_as_complete
      end

      def protect_method(method_name)
        method_name = method_name.to_sym
        return unless restricted_methods.include?(method_name)
        return if method_already_protected?(method_name)
        mark_method_as_already_protected(method_name)
        @class.class_exec(method_name) do |method_name|
          new_impl = :"#{method_name}_with_protection"
          original_impl = :"#{method_name}_without_protection"
          define_method(new_impl) do |*args, &block|
            AccessControl.manager.can!(self.class.permissions_for(method_name),
                                       self)
            send(original_impl, *args, &block)
          end
          alias_method original_impl, method_name
          alias_method method_name, new_impl
        end
      end

    private

      def method_protection_complete?
        !!@class.instance_variable_get(:"@__method_protection_complete__")
      end

      def defined_restricted_methods
        restricted_methods.select{ |m| @class.method_defined?(m) }
      end

      def restricted_methods
        Registry.query(:__ac_class__ => @class_name).inject([]) do |m, p|
          Registry.all_with_metadata[p].each do |metadata|
            if metadata.include?(:__ac_method__)
              m << metadata[:__ac_method__]
            end
          end
          m
        end
      end

      def mark_method_protection_as_complete
        @class.instance_variable_set(:"@__method_protection_complete__", true)
      end

      def method_already_protected?(method_name)
        methods_already_protected.include?(method_name)
      end

      def methods_already_protected
        unless v = @class.instance_variable_get(:"@__methods_protected__")
          v = @class.instance_variable_set(:"@__methods_protected__", Set.new)
        end
        v
      end

      def mark_method_as_already_protected(method_name)
        methods_already_protected << method_name
      end

    end

    module ClassMethods

      def protect method_name, options
        Protector.new(self).set_permissions_for(method_name, options)
      end

      def permissions_for method_name
        Protector.new(self).get_permissions_for(method_name)
      end

      unless AccessControl::Util.new_calls_allocate?
        def new *args
          Protector.new(self).protect_methods
          super
        end
      end

      def allocate
        Protector.new(self).protect_methods
        super
      end

    end
  end
end
