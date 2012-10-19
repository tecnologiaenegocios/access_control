module WithConstants
  module SubclassGuard
    def inherited(subclass)
      unless subclass.name.blank? # Defer until subclass has a proper name.
        super
      end
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
    end
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
      example.instance_eval(&value) if value
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

  module ExampleMethods
    def let_constant(ref_name, &block)
      let(ref_name) { instance_eval(&block) }
      declared_constants[ref_name] = lambda { send(ref_name) }
    end

    def it(*args, &block)
      if block
        super(*args) { with_declared_constants { instance_eval(&block) } }
      else
        super
      end
    end

    def specify(*args, &block)
      if block
        super(*args) { with_declared_constants { instance_eval(&block) } }
      else
        super
      end
    end

    def before(*args, &block)
      super(*args) { with_declared_constants { instance_eval(&block) } }
    end
    def after(*args, &block)
      super(*args) { with_declared_constants { instance_eval(&block) } }
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
      base.instance_eval { remove_const(constant.name) }
    end

    saved_constants.each do |name, constant|
      Kernel.silence_warnings { base.const_set(name, constant) }
    end
  end

  def new_class(name, *args, &block)
    Class.new(*args) do
      extend(SubclassGuard)
      NamedConstant.add_name(self, name)
      # Now that we have a name, trigger .inherited hook on superclass.
      if superclass.respond_to?(:inherited)
        superclass.inherited(self)
      end
      class_eval(&block) if block
    end
  end

  def new_module(name, &block)
    Module.new do
      NamedConstant.add_name(self, name)
      module_eval(&block) if block
    end
  end

private

  def declared_constants
    @declared_constants ||= self.class.declared_constants.evaluate_all(self)
  end
end
