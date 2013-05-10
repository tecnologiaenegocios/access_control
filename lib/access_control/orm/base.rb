module AccessControl
  module ORM
    class Base
      attr_reader :object

      def name
        object.name
      end

      # Forwards the instantiation of the underlying object.
      #
      # For all purposes, instantiating the adapted class or the underlying
      # class object itself returns an object with the same interface.  The
      # simplest way to achieve this is by delegating instantiation and using
      # instances directly from the underlying ORM.
      def new(attributes={})
        object.new.tap do |instance|
          attributes.each do |attribute, value|
            instance.public_send(:"#{attribute}=", value)
          end
        end
      end

      def pk_of(instance)
        instance.send(pk_name)
      end
    end
  end
end
