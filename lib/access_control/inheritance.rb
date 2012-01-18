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
      inheritances[model]
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

    def self.inheritances
      @inheritances ||= Hash.new do |hash, model|
        model_name = model.kind_of?(String) ? model : model.name

        if hash.has_key?(model_name)
          hash[model_name]
        else
          hash[model_name] = Array.new
        end
      end
    end

    private_class_method :inheritances

    def self.add_inheritance(model, inheritance)
      equivalent_exists = inheritances[model].any? do |other|
        other == inheritance
      end

      inheritances[model] << inheritance unless equivalent_exists
    end

    private_class_method :add_inheritance

    module ClassMethods
      def inherits_permissions_from(*args)
        unless args.any? || @__inheritance__.nil?
          @__inheritance__
        else
          associations = args.flatten(1)
          @__inheritance__ = associations.flat_map(&:to_sym)
        end
      end

      def inherits_permissions_from_key(key_name, options)
        class_name = options[:class_name]

        unless class_name && key_name
          raise ArgumentError, "Key and class names are mandatory"
        end

        Inheritance.add_key_inheritance(self, key_name, options)
      end
    end

  end
end
