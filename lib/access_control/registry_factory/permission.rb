module AccessControl
  class RegistryFactory
    class Permission
      attr_reader :name, :controller_action, :context_designator

      def initialize(name = "")
        @name = name
      end

      def context_designator
        @context_designator ||= {}
      end

      def controller_action
        @controller_action ||= Set.new
      end
    end
  end
end
