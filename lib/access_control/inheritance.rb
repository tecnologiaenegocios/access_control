require 'access_control/exceptions'
require 'access_control/manager'

module AccessControl
  module Inheritance

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def inherits_permissions_from *args
        @__inheritance__ =
          if args.any?
            args.flatten.inject([]) { |items, assoc| items << assoc.to_sym }
          else
            @__inheritance__ || []
          end
      end
    end

  end
end
