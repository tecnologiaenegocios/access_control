require 'access_control/registry'
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

      def set_permissions_for(method_name, permission_name, &block)
        Registry.store(permission_name) do |permission|
          permission.ac_methods << [@class_name, method_name.to_sym]
          permission.ac_classes << @class_name
          block.call(permission) if block
        end
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

        new_impl = :"#{method_name}_with_protection"
        original_impl = :"#{method_name}_without_protection"
        query_key = [@class_name, method_name]

        @class.class_eval(<<-METHOD, __FILE__, __LINE__ + 1)
          def #{new_impl}(*args, &block)
            p = Registry.query(:ac_methods => [#{query_key.inspect}])
            AccessControl.manager.can!(p.map(&:name), self)
            #{original_impl}(*args, &block)
          end

          alias_method :#{original_impl}, :#{method_name}
          alias_method :#{method_name},   :#{new_impl}
        METHOD
      end

    private

      def method_protection_complete?
        !!@class.instance_variable_get(:"@__method_protection_complete__")
      end

      def defined_restricted_methods
        restricted_methods.select{ |m| @class.method_defined?(m) }
      end

      def restricted_methods
        Registry.query(:ac_classes => [@class_name]).flat_map do |p|
          p.ac_methods.select { |k, m| k == @class_name }.map { |k, m| m }
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

      def protect(method_name, options, &block)
        permission_name = options[:with]
        Protector.new(self).set_permissions_for(method_name, permission_name,
                                                &block)
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
