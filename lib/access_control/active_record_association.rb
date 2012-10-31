require 'access_control/transaction'

module AccessControl
  class ActiveRecordAssociation
    def initialize(instance, &block)
      @instance  = instance
      @names     = self.class.associated_names[instance.class]
      @block     = block
    end

    def run
      instance_eval(&@block)
    end

    def persist
      return if AccessControl.disabled?

      @names.each do |name, key_method|
        unless @instance.new_record?
          associated = @instance.send(name)
          pk_method  = @instance.class.primary_key
          associated.send(:"#{key_method}=", @instance.send(pk_method))
          associated.persist!
        end
      end
    end

    def destroy
      return if AccessControl.disabled?

      @names.each do |name, key_method|
        if @instance.destroyed?
          @instance.send(name).destroy
        end
      end
    end

    def self.setup_association(name, key_method, base, &block)
      base.class_eval do
        include AssociationSupport
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

    module AssociationSupport
      module ClassMethods
        def transaction(*)
          if block_given?
            super { Transaction.current.run { yield } }
          else
            super
          end
        end
      end

      def save(*)
        AssociationSupport.add(self) { persist }
        super
      end

      def save!
        AssociationSupport.add(self) { persist }
        super
      end

      def destroy
        AssociationSupport.add(self) { destroy }
        super
      end

      class << self
        def included(base)
          base.extend(ClassMethods)
        end

        def add(instance, &block)
          association = ActiveRecordAssociation.new(instance, &block)
          Transaction.current.add(association)
        end
      end
    end

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
  end
end
