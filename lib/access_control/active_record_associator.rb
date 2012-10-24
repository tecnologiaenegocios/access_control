module AccessControl
  class ActiveRecordAssociator
    class AssociatedNames
      def initialize
        @container = Hash.new { |h, k| h[k] = Set.new }
      end

      def add(klass, name, key_method)
        @container[klass.name].add([name, key_method])
      end

      def [] klass
        @container[klass.name] | from_superclass(klass)
      end

    private

      def from_superclass(klass)
        if klass == ActiveRecord::Base
          return Set.new
        else
          self[klass.superclass]
        end
      end
    end

    module Boilerplate
    private
      def __associator__
        @__associator__ ||= ActiveRecordAssociator.new(self)
      end
    end

    def self.setup_association(name, key_method, base, &block)
      base.class_eval do
        include Boilerplate

        after_create  { |record| record.send(:__associator__).persist }
        after_update  { |record| record.send(:__associator__).sync }
        after_destroy { |record| record.send(:__associator__).destroy }

        define_method(name, &block)
      end

      associated_names.add(base, name, key_method)
    end

    def self.associated_names
      @associated_names ||= AssociatedNames.new
    end

    def self.clear
      @associated_names = nil
    end

    def initialize(instance)
      @instance = instance
      @names    = ActiveRecordAssociator.associated_names[instance.class]
    end

    def persist
      @names.each do |name, key_method|
        associated = @instance.send(name)
        pk_method  = @instance.class.primary_key
        associated.send(:"#{key_method}=", @instance.send(pk_method))
        associated.persist!
      end
    end

    def sync
      @names.each do |name, key_method|
        associated = @instance.send(name)
        associated.persist!
      end
    end

    def destroy
      @names.each { |name, key_method| @instance.send(name).destroy }
    end
  end
end
