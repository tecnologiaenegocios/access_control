module AccessControl

  # Test if Class#new calls Class#allocate when Class#allocate is overridden.
  #
  # In some Ruby implementations, like Rubinius, #new calls #allocate even if
  # it is overridden, unlike in MRI where #new calls only the C implementation
  # of #allocate (effectively skipping the overridden implementation).  So in
  # the platforms where #new calls the overridden #allocate we don't do our
  # dark wizardry for instance creation twice, since it is enough to do it by
  # overriding #allocate.  On the other hand, if #new only calls the low-level
  # implementation, we need to do our magic in #new and #allocate.
  #
  # But why the hell one wants to override #allocate?  Isn't #new just as good?
  # No.  ActiveRecord calls #allocate to create instances from #find, and even
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

    module ClassMethods

      def protect method_name, options
        Registry.register(permissions = options[:with], options[:data] || {})
        permissions_for_methods[method_name.to_s].merge(permissions)
      end

      def permissions_for method_name
        permissions_for_methods[method_name.to_s]
      end

      def new *args
        return super if AccessControl.new_calls_allocate?
        instance = super
        protect_methods!(instance)
        instance
      end

      def allocate
        instance = super
        protect_methods!(instance)
        instance
      end

    private

      def permissions_for_methods
        @ac_permissions_for_methods ||= Hash.new{|h, k| h[k] = Set.new}
      end

      def protect_methods! instance
        permissions_for_methods.keys.each do |m|
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
