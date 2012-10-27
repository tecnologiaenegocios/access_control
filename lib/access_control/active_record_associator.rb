module AccessControl
  class ActiveRecordAssociator
    def initialize(instance)
      @instance = instance
      @names    = ActiveRecordAssociator.associated_names[instance.class]
    end

    def persist
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
      @names.each do |name, key_method|
        if @instance.destroyed?
          @instance.send(name).destroy
        end
      end
    end

    def self.setup_association(name, key_method, base, &block)
      base.class_eval do
        include AssociatorSupport
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

    module AssociatorSupport
      module ClassMethods
        def transaction(*)
          if block_given?
            super { AssociatorSupport.transaction { yield } }
          else
            super
          end
        end
      end

      def save(*)
        AssociatorSupport.add_associator_to_persist(self)
        super
      end

      def save!
        AssociatorSupport.add_associator_to_persist(self)
        super
      end

      def destroy
        AssociatorSupport.add_associator_to_destroy(self)
        super
      end

      class << self
        def included(base)
          base.extend(ClassMethods)
        end

        def add_associator_to_persist(instance)
          associators_to_persist << ActiveRecordAssociator.new(instance)
        end

        def add_associator_to_destroy(instance)
          associators_to_destroy << ActiveRecordAssociator.new(instance)
        end

        def transaction
          increment_transaction_counter
          yield
          synchronize_associators if transaction_counter == 1
        ensure
          decrement_transaction_counter
          clear if transaction_counter == 0
        end

      private

        def associators_to_persist
          Thread.current[:active_record_associators_to_persist] ||= []
        end

        def associators_to_destroy
          Thread.current[:active_record_associators_to_destroy] ||= []
        end

        def transaction_counter
          Thread.current[:active_record_associator_transactions] ||= 0
        end

        def increment_transaction_counter
          Thread.current[:active_record_associator_transactions] =
            transaction_counter + 1
        end

        def decrement_transaction_counter
          Thread.current[:active_record_associator_transactions] =
            transaction_counter - 1
        end

        def synchronize_associators
          associators_to_persist.each { |associator| associator.persist }
          associators_to_destroy.each { |associator| associator.destroy }
        ensure
          clear
        end

        def clear
          associators_to_persist.clear
          associators_to_destroy.clear
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
