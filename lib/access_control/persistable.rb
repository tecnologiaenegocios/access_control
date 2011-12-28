require 'access_control/exceptions'
require 'access_control/persistable/wrapper_scope'

module AccessControl
  module Persistable
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval { undef_method(:id) if method_defined?(:id) }
    end

    def initialize(properties={})
      self.class.ensure_delegation
      properties.each do |name, value|
        public_send(:"#{name}=", value)
      end
    end

    def persistent
      @persistent ||= self.class.persistent_model.new
    end

    def persisted?
      !persistent.new_record?
    end

    def persist
      persistent.save
    end

    def persist!
      raise RecordNotPersisted unless persist
      self
    end

    def destroy
      persistent.destroy
    end

    def == other
      if other.kind_of?(self.class)
        other.persistent == persistent
      else
        false
      end
    end

    def to_param
      persistent.to_param
    end

    module ClassMethods
      def wrap(object)
        ensure_delegation
        allocate.tap do |persistable|
          persistable.instance_variable_set('@persistent', object)
        end
      end

      def store(properties)
        persistable = new(properties)
        persistable.persist!
      end

      def all
        WrapperScope.new(self, persistent_model.all)
      end

      def fetch(id, default_value = marker)
        found = persistent_model.find_by_id(id)
        return wrap(found) if found

        return yield if block_given?

        default_value.tap do |value|
          raise NotFoundError if value.eql?(marker)
        end
      end

      def fetch_all(ids)
        results = persistent_model.all(:conditions => { :id => ids })
        raise NotFoundError if results.size != ids.size
        results.map { |result| wrap(result) }
      end

      def has?(id)
        persistent_model.exists?(id)
      end

      def count
        persistent_model.count
      end

      def delegate_scope(*scope_names)
        meta = (class << self; self; end)

        scope_names.each do |scope_name|
          meta.class_eval do
            define_method(scope_name) do |*args|
              scope = persistent_model.public_send(scope_name, *args)
              WrapperScope.new(self, scope)
            end
          end
        end

        delegated_scopes.concat(scope_names)
        delegated_scopes.uniq!
      end

      alias_method :delegate_scopes, :delegate_scope

      def delegated_scopes
        @__persistable_delegated_scopes__ ||= []
      end

      def ensure_delegation
        unless delegated?
          readers = persistent_model.column_names
          writers = readers.map { |name| "#{name}=" }

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

          mark_as_delegated
        end
      end

    private

      def marker
        @marker ||= Object.new
      end

      def delegated?
        !!@__persistable_class_done_delegation__
      end

      def mark_as_delegated
        @__persistable_class_done_delegation__ = true
      end
    end
  end
end
