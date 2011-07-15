module Introspection
  def it_has_instance_method(klass, method, arity=nil)
    attribute = false
    if klass.superclass == ActiveRecord::Base &&
       klass.column_names.include?(method.to_s)
      attribute = true
    end
    it "#{klass.name} has instance method #{method}" do
      unless attribute
        klass.instance_methods.should include(method.to_s)
      end
    end
    if arity
      msg = arity == 1 ? 'argument' : 'arguments'
      specify "#{klass.name}##{method} accepts #{arity} #{msg}" do
        klass.instance_method(method).arity.should == arity
      end
    end
  end
  def it_has_class_method(klass, method, arity=nil)
    it "#{klass.name} has class method #{method}" do
      klass.methods.should include(method.to_s)
    end
    if arity
      msg = arity == 1 ? 'argument' : 'arguments'
      specify "#{klass.name}.#{method} accepts #{arity} #{msg}" do
        klass.method(method).arity.should == arity
      end
    end
  end
end
