require 'ostruct'

module AccessControl
  class RegistryFactory
    class Permission
      attr_accessor :name, :controller_action, :ac_context

      def initialize(name = "")
        @name = name
        @ac_context = {}
      end
    end
  end
end
