module AccessControl
  class RegistryFactory
    class Permission
      attr_accessor :name, :controller_action, :ac_context

      def initialize(name = "")
        @name = name
      end

      def ac_context
        @ac_context ||= {}
      end

      def controller_action
        @controller_action ||= Set.new
      end
    end
  end
end
