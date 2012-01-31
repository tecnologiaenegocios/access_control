module AccessControl
  class RegistryFactory
    class Permission
      attr_reader :name, :ac_methods, :context_designator

      def initialize(name = "")
        @name = name
      end

      def context_designator
        @context_designator ||= {}
      end

      def ac_methods
        @ac_methods ||= Set.new
      end
    end
  end
end
