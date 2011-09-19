require 'access_control/registry'

module AccessControl

  # Test if Class#new calls Class#allocate when Class#allocate is overridden.
  #
  # In some Ruby implementations, like Rubinius, .new calls .allocate even if
  # it is overridden, unlike in MRI where .new calls only the C implementation
  # of #allocate (effectively skipping the overriding implementation).  So in
  # the platforms where .new calls the overridden .allocate we don't do our
  # dark wizardry for instance creation twice, since it is enough to do it by
  # overriding .allocate.  On the other hand, if .new only calls the low-level
  # implementation directly, we need to do our magic in .allocate and in .new
  # as well.
  #
  # But why the hell one wants to override .allocate?  Isn't .new just as good?
  # No.  ActiveRecord calls .allocate to create instances from .find, and even
  # then we want our funny tricks working.
  def self.new_calls_allocate?
    return @new_calls_allocate unless @new_calls_allocate.nil?
    @new_calls_allocate = false
    klass = Class.new do
      def self.allocate
        AccessControl.new_calls_allocate!
        super
      end
    end
    klass.new
    @new_calls_allocate
  end

  def self.new_calls_allocate!
    @new_calls_allocate = true
  end

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

      unless AccessControl.new_calls_allocate?
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
