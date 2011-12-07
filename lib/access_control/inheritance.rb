require 'access_control/exceptions'
require 'access_control/manager'
require 'backports'

module AccessControl
  module Inheritance

    def self.included(base)
      base.extend(ClassMethods)
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
