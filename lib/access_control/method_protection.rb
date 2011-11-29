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
        return if methods_protected?
        restricted_methods.each do |m|
          if @class.method_defined?(m)
            define_using_alias_method(m)
          else
            define_using_super(m)
          end
        end
        mark_methods_as_protected
      end

    private

      def methods_protected?
        !!@class.instance_variable_get(:"@__methods_protected__")
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

      def define_using_alias_method(method_name)
        @class.class_exec(method_name) do |method_name|
          new_name = :"#{method_name}_with_protection"
          original_name = :"#{method_name}_without_protection"
          define_method(new_name) do |*args, &block|
            AccessControl.manager.can!(self.class.permissions_for(method_name),
                                       self)
            send(original_name, *args, &block)
          end
          alias_method original_name, method_name
          alias_method method_name, new_name
        end
      end

      def define_using_super(method_name)
        @class.class_exec(method_name) do |method_name|
          define_method(method_name) do |*args, &block|
            AccessControl.manager.can!(self.class.permissions_for(method_name),
                                       self)
            super(*args, &block)
          end
        end
      end

      def mark_methods_as_protected
        @class.instance_variable_set(:"@__methods_protected__", true)
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
