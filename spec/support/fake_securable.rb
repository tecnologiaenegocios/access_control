# vim: fdm=marker:fdl=0

require 'active_support/core_ext/module'
require 'active_support/core_ext/class'

# Documentation {{{
#
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
# Struct/OpenStruct-like behavior {{{
#
# By default, the classes present a Struct/OpenStruct-like behavior on
# initialization, making the customization and instantiation straightforward.
# Example:
#
# securable_class = FakeSecurableClass.new(:name)
# securable = securable_class.new(:name => "Securable")
# securable.name
#  => "Securable"
#
# It's also worth mentioning that the 'attributes' listed on the
# FakeSecurableClass::DEFAULT_ACCESSORS constant are always added to the
# classes.
#
# }}}
#
# Passing blocks to FakeSecurableClass.new {{{
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
#
# }}}
#
# }}}

module AccessControl
  module FakeSecurableClass
    DEFAULT_ACCESSORS = %w[ac_node]

    def self.new(*accessors, &block)
      new_class = Class.new
      new_class.send(:include, FakeSecurableMethods)
      new_class.send(:extend,  FakeSecurableClassMethods)
      new_class.send(:include, Inheritance)

      accessors.concat DEFAULT_ACCESSORS
      new_class.send(:attr_accessor, *accessors)

      if block_given?
        new_class.class_exec(&block)
      end

      new_class
    end
  end

  module FakeSecurableMethods
    attr_reader :id

    include Securable

    def initialize(attributes = {})
      attributes.each do |name, value|
        setter_name = :"#{name}="
        public_send(setter_name, value)
      end
    end

    def ==(other)
      other.class == self.class && other.id == self.id
    end

    def inspect
      variables_list = instance_variables.map do |variable_name|
        variable_value = instance_variable_get(variable_name)
        [variable_name, variable_value.inspect].join("=")
      end

      hex_object_id = sprintf '0x%x', 2 * object_id

      if variables_list.empty?
        "#<FakeSecurable:#{hex_object_id}>"
      else
        variables_desc = variables_list.join(" ")
        "#<FakeSecurable:#{hex_object_id} #{variables_desc}>"
      end
    end

    alias_method :to_s, :inspect
  end

  module FakeSecurableClassMethods
    def find(id)
      instances_store.fetch(id)
    end
    alias_method :unrestricted_find, :find

    alias_method :name, :to_s

    def new(*args, &block)
      options = args.extract_options!
      new_instance_id = options.delete(:id) || increment_instance_counter()

      forwarded_options = args.push(options)
      new_instance = super(*forwarded_options, &block)

      new_instance.instance_variable_set("@id", new_instance_id)

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
