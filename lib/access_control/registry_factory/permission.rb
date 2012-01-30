require 'ostruct'

module AccessControl
  class RegistryFactory
    class Permission < OpenStruct
      def initialize(name = "")
        super(:name => name)
      end
    end
  end
end
