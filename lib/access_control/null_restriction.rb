module AccessControl
  module NullRestriction
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def listable(*args, &block)
        scoped({})
      end

      def unrestricted_find(*args, &block)
        find(*args, &block)
      end
    end
  end
end
