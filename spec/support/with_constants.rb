module WithConstants
  def with_declared_constants
    with_constants(*declared_constants) { yield }
  end

  def with_constants(*args)
    options         = args.last.is_a?(Hash) ? args.pop : {}
    constants       = args
    base            = options.fetch(:base, Object)
    saved_constants = {}

    constants.each do |constant|
      name = constant.name.to_sym
      if base.const_defined?(name)
        saved_constants[name] = base.const_get(name)
      end
      Kernel.silence_warnings { base.const_set(name, constant) }
    end

    yield
  ensure
    constants.each do |constant|
      base.instance_exec { remove_const(constant.name) }
    end

    saved_constants.each do |name, constant|
      Kernel.silence_warnings { base.const_set(name, constant) }
    end
  end

  def new_class(name, sup, &block)
    InheritanceGuardedClass.subclass_with_name(name, sup, &block)
  end

  def new_module(name, &block)
    Module.new do
      NamedConstant.add_name(self, name)
      module_eval(&block) if block
    end
  end

  module ExampleMethods
    def let_constant(ref_name, &block)
      let(ref_name) { instance_exec(&block) }
      declared_constants[ref_name] = lambda { send(ref_name) }
    end

    def it(*args, &block)
      if block
        super(*args) { with_declared_constants { instance_exec(&block) } }
      else
        super
      end
    end

    def specify(*args, &block)
      if block
        super(*args) { with_declared_constants { instance_exec(&block) } }
      else
        super
      end
    end

    def before(*args, &block)
      super(*args) { with_declared_constants { instance_exec(&block) } }
    end
    def after(*args, &block)
      super(*args) { with_declared_constants { instance_exec(&block) } }
    end
    def run(*args)
      super
    ensure
      # A cleanup is needed: when securable classes have inheritance and/or
      # permission declarations, global state is left in some AccessControl
      # objects.
      AccessControl.reset
    end

    def declared_constants
      @declared_constants ||= DeclaredConstants.new(self)
    end
  end

  def self.included(base)
    base.extend(ExampleMethods)
  end

private

  def declared_constants
    @declared_constants ||= self.class.declared_constants.evaluate_all(self)
  end

  class DeclaredConstants
    def initialize(owner)
      @owner = owner
      @declared_constants = {}
    end

    def [](name)
      declared_constants[name] || superclass_declared_constants[name]
    end

    def []=(name, block)
      declared_constants[name] = block
    end

    def keys
      declared_constants.keys | superclass_declared_constants.keys
    end

    def values
      keys.map { |key| self[key] }
    end

    def evaluate(example, name)
      value = self[name]
      example.instance_exec(&value) if value
    end

    def evaluate_all(example)
      keys.map { |key| self.evaluate(example, key) }
    end

  private
    attr_reader :owner, :declared_constants

    def superclass_declared_constants
      if superclass.include?(WithConstants)
        superclass.declared_constants
      else
        {}
      end
    end

    def superclass
      owner.superclass
    end
  end

  module InheritanceGuardedClass
    def self.subclass_with_name(name, sup, &block)
      # Ensure a .inherited hook exists.
      if !sup.respond_to?(:inherited)
        sup.define_singleton_method(:inherited) { |child| }
      end

      sup.class_eval do
        # Prevent .inherited hook from running in anonymous child classes.
        class << self
          define_method(:dummy_inherited) { |child| }
          alias_method :original_inherited, :inherited
          alias_method :inherited, :dummy_inherited
        end
      end

      sub = NamedConstant.new_class(sup, name)

      sup.class_eval do
        class << self
          alias_method :inherited, :original_inherited
          undef :dummy_inherited
        end
      end

      # Now that the child has a name, trigger .inherited hook on superclass.
      sup.inherited(sub)

      sub.class_eval(&block) if block
      sub
    end
  end

  module NamedConstant
    class << self
      def add_name(constant, name)
        name = name.to_s
        constant.define_singleton_method(:name) { name }
        # This is bizarre: #to_s calls #name only if the class/module is not
        # anonymous.
        constant.define_singleton_method(:to_s) { name }
      end

      def new_class(sup, name)
        Class.new(sup) { NamedConstant.add_name(self, name) }
      end
    end
  end
end
