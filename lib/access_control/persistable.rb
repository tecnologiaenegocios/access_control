require 'access_control/exceptions'
require 'access_control/persistable/wrapper_scope'

module AccessControl
  module Persistable
    def self.included(base)
      base.extend(ClassMethods)
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

    def == other
      if other.kind_of?(self.class)
        other.persistent == persistent
      else
        false
      end
    end

    module ClassMethods
      def wrap(object)
        ensure_delegation
        allocate.tap do |persistable|
          persistable.instance_variable_set('@persistent', object)
        end
      end

      def store(properties)
        persistable = wrap(persistent_model.new(properties))
        raise RecordNotPersisted unless persistable.persist
        persistable
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

      def has?(id)
        persistent_model.exists?(id)
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
          delegate(*readers.push(:to => :persistent))
          delegate(*writers.push(:to => :persistent))
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
