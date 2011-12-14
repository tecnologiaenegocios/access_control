require 'backports'

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

    module ClassMethods
      def inherits_permissions_from(*args)
        unless args.any? || @__inheritance__.nil?
          @__inheritance__
        else
          associations = args.flatten(1)
          @__inheritance__ = associations.flat_map(&:to_sym)
        end
      end
    end

  end
end
