module AccessControl
  class Permission < OpenStruct
    def initialize(name = "")
      super(:name => name)
    end
  end
end
