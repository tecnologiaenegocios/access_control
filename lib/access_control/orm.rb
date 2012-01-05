module AccessControl
  module ORM
    class Base
      attr_reader :object
      # The name of the class, as a symbol.
      def name
        object.name.to_sym
      end

      # Forwards the instantiation of the underlying object.
      #
      # For all purposes, instantiating the adapted class or the underlying
      # class object itself returns an object with the same interface.  The
      # simplest way to achieve this is by delegating instantiation and using
      # instances directly from the underlying ORM.
      def new
        object.new
      end
    end

    def self.adapt_class(object)
      # We only support ActiveRecord::Base by now.
      ActiveRecordClass.new(object)
    end

  end
end
