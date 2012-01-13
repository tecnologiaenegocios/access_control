require 'access_control/exceptions'
require 'access_control/persistable/wrapped_subset'

module AccessControl
  module Persistable
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval { undef_method(:id) if method_defined?(:id) }
    end

    def initialize(properties={})
      self.class.__persistable_ensure_delegation__
      properties.each do |name, value|
        public_send(:"#{name}=", value)
      end
    end

    def persistent
      @persistent ||= self.class.persistent_model.new
    end

    def persisted?
      self.class.persistent_model.persisted?(persistent)
    end

    def persist
      self.class.persistent_model.persist(persistent)
    end

    def persist!
      raise RecordNotPersisted unless persist
      self
    end

    def destroy
      self.class.persistent_model.delete(persistent)
    end

    def == other
      if other.kind_of?(self.class)
        self.class.persistent_model.instance_eql?(persistent, other.persistent)
      else
        false
      end
    end

    def to_param
      persistent.to_param
    end

    def hash
      persistent.hash
    end

    def inspect
      persistent_desc  = persistent.inspect
      persistent_class = persistent.class.to_s

      persistent_desc.gsub(persistent_class, self.class.name)
    end

    module ClassMethods
      def wrap(object)
        __persistable_ensure_delegation__
        allocate.tap do |persistable|
          persistable.instance_variable_set('@persistent', object)
        end
      end

      def store(properties)
        persistable = new(properties)
        persistable.persist!
      end

      def all
        WrappedSubset.new(self, persistent_model.values)
      end

      def fetch(id, default_value = Persistable::MARKER)
        found = persistent_model[id]
        return wrap(found) if found

        return yield if block_given?

        default_value.tap do |value|
          raise NotFoundError if value.eql?(Persistable::MARKER)
        end
      end

      def fetch_all(ids)
        results = persistent_model.values_at(*ids)
        raise NotFoundError if results.size != ids.size
        results.map { |result| wrap(result) }
      end

      def has?(id)
        persistent_model.include?(id)
      end

      def count
        persistent_model.size
      end

      def delegate_subset(*subset_names)
        meta = (class << self; self; end)

        subset_names.each do |subset_name|
          meta.class_eval do
            define_method(subset_name) do |*args|
              subset = persistent_model.subset(subset_name, *args)
              WrappedSubset.new(self, subset)
            end
          end
        end

        delegated_subsets.concat(subset_names)
        delegated_subsets.uniq!
      end

      alias_method :delegate_subsets, :delegate_subset

      def delegated_subsets
        @__persistable_delegated_subsets__ ||= []
      end

      def __persistable_ensure_delegation__
        unless __persistable_delegated__?
          readers = persistent_model.column_names
          writers = readers.map { |name| :"#{name}=" }

          readers.delete_if { |name| method_defined?(name) }
          writers.delete_if { |name| method_defined?(name) }

          readers.each do |reader|
            define_method(reader) do
              persistent.public_send(reader)
            end
          end

          writers.each do |writer|
            define_method(writer) do |value|
              persistent.public_send(writer, value)
            end
          end

          __persistable_mark_as_delegated__
        end
      end

    private

      def __persistable_delegated__?
        !!@__persistable_class_done_delegation__
      end

      def __persistable_mark_as_delegated__
        @__persistable_class_done_delegation__ = true
      end
    end

    MARKER = Object.new
  end
end
