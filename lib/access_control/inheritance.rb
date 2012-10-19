require 'backports'
require 'access_control/association_inheritance'
require 'access_control/method_inheritance'

module AccessControl
  module Inheritance

    def self.included(base)
      base.extend(ClassMethods)
    end

    def self.recognizes?(object)
      if object.kind_of?(Class)
        object.include?(self)
      else
        object.class.include?(self)
      end
    end

    def self.inheritances_of(model)
      this_inheritances = inheritances[model]
      if this_inheritances.empty? && model.superclass != Object
        this_inheritances = inheritances_of(model.superclass)
      end
      this_inheritances
    end

    def self.parent_node_ids_of(securable)
      inheritances = inheritances_of(securable.class)
      inheritances.flat_map { |inheritance|
        relationships = inheritance.relationships_of([securable])
        relationships.map { |relationship| relationship.fetch(:parent_id) }
      }.uniq
    end

    def self.add_key_inheritance(model, key_name, class_name)
      AssociationInheritance.new(model, key_name, class_name).tap do |inheritance|
        add_inheritance(model, inheritance)
      end
    end

    def self.add_method_inheritance(model, method_name)
      MethodInheritance.new(model, method_name).tap do |inheritance|
        add_inheritance(model, inheritance)
      end
    end

    def self.add_inheritance(model, inheritance)
      equivalent_exists = inheritances[model].any? do |other|
        other == inheritance
      end

      inheritances[model] << inheritance unless equivalent_exists
    end

    def self.inheritances
      @inheritances ||= Hash.new do |hash, model|
        model_name = model.name

        if hash.has_key?(model_name)
          hash[model_name]
        else
          hash[model_name] = Array.new
        end
      end
    end
    private_class_method :inheritances

    def self.clear
      @inheritances = nil
    end


    module ClassMethods
      def inherits_permissions_from(*methods)
        inheritances = methods.map do |method_name|
          Inheritance.add_method_inheritance(self, method_name)
        end
        inheritances.size == 1 ? inheritances.first : inheritances
      end

      def inherits_permissions_from_key(key_name, options)
        class_name = options[:class_name]

        unless class_name && key_name
          raise ArgumentError, "Key and class names are mandatory"
        end

        Inheritance.add_key_inheritance(self, key_name, class_name)
      end
    end

  end
end
