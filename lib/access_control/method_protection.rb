require 'access_control/registry'
require 'access_control/util'

module AccessControl
  module MethodProtection

    def self.included(base)
      base.extend(ClassMethods)
    end

    class Protector
      def initialize(klass)
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
          instance = super
          protect_methods!(instance)
          instance
        end
      end

      def allocate
        instance = super
        protect_methods!(instance)
        instance
      end

    private

      def protect_methods! instance
        Protector.new(self).restricted_methods.each do |m|
          (class << instance; self; end;).class_eval do
            define_method(m) do
              AccessControl.manager.can!(
                self.class.permissions_for(__method__),
                self
              )
              super
            end
          end
        end
      end

    end
  end
end
