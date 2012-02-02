module AccessControl
  class RegistryFactory
    class Permission
      attr_reader :name

      def initialize(name = "")
        @name = name
      end

      def context_designator
        @context_designator ||= {}
      end

      def ac_methods
        @ac_methods ||= Set.new
      end

      def ac_classes
        @ac_classes ||= Set.new
      end

      def inspect
        default = super
        prefix  = default[/^.* /]
        "#{prefix}#{name.inspect}>"
      end
    end
  end
end
