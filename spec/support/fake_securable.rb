require 'active_support/core_ext/module'
require 'active_support/core_ext/class'

# A 'fixture' class used to clean the Node class tests. All the behaviour is
# implemented on the FakeSecurableMethods module, which is included on the
# FakeSecurable class and its anonymous brothers (that can be created by using
# FakeSecurableClass.new). The non-traditional (and somewhat non-trivial)
# layout was used so that a programmer can mess up with the class (include
# modules, use .stub, define methods on the eigenclass etc) and still maintain
# test orthogonality. This may be achieved using a 'let' or some similar
# construct:
#
# let(:securable_class) { FakeSecurableClass.new }
#
# By using that approach, 'securable_class' will be an entirely new class on
# each test.
#
# On the occasion where specific methods and/or inclusions are needed, it is
# possible to pass a block to the FakeSecurableClass.new method, and that
# block will be 'class_exec'd on the context of the new class. Example:
#
# my_securable_class = FakeSecurableClass.new do
#   include Inheritance
#
#   attr_accessor :name
#   def initialize(name)
#     @name = name
#   end
# end
#
# securable = my_securable_class.new("Securable")
# => #<FakeSecurable:0x3f9bdf31c79c @name="Securable" @id=1>
#
# securable.name
# => "Securable"
#
# securable.is_a?(Inheritance)
# => true

module AccessControl
  module FakeSecurableClass
    def self.new(*args, &block)
      new_class = Class.new(*args, &block)
      new_class.send(:include, FakeSecurableMethods)
      new_class.send(:extend,  FakeSecurableClassMethods)
    end
  end

  module FakeSecurableMethods
    attr_reader :id
    def initialize(id)
      @id = id
    end

    def inspect
      hex_object_id = sprintf '0x%x', object_id
      "#<FakeSecurable:#{hex_object_id} @id=#{id}>"
    end
    alias_method :to_s, :inspect

  end

  module FakeSecurableClassMethods
    def unrestricted_find(id)
      instances_store.fetch(id)
    end

    def new
      new_instance_id = increment_instance_counter()
      new_instance = super(new_instance_id)

      store_instance(new_instance_id, new_instance)
    end

    def increment_instance_counter
      @instance_counter ||= 0
      @instance_counter += 1
    end

    def store_instance(id, instance)
      instances_store.store(id, instance)
    end

    def instances_store
      @instances_store ||= Hash.new
    end
  end

  FakeSecurable = FakeSecurableClass.new
end
