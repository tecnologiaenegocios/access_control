module WithConstants
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

  module ExampleMethods
    def let_class(name, superclass, &block)
      name = name.to_s
      declared_constants[name] = Class.new(superclass).tap do |klass|
        klass.define_singleton_method(:name) { name }

        # This is bizarre: #to_s calls #name only if the class/module is not
        # anonymous.
        def klass.to_s
          name
        end

        klass.class_eval(&block)
      end
    end

    def let_active_record(name, &block)
      let_class(name, ActiveRecord::Base, &block)
    end

    def it(*args, &block)
      super(*args) { with_declared_constants { instance_eval(&block) } }
    end
    def specify(*args, &block)
      super(*args) { with_declared_constants { instance_eval(&block) } }
    end
    def before(*args, &block)
      super(*args) { with_declared_constants { instance_eval(&block) } }
    end
    def after(*args, &block)
      super(*args) { with_declared_constants { instance_eval(&block) } }
    end

    def declared_constants
      @declared_constants ||= {}
    end
  end

private

  def declared_constants
    @declared_constants ||= self.class.declared_constants.values
  end
end
