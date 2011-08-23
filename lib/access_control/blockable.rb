module AccessControl
  class Blockable

    attr_reader :model

    def initialize(model)
      @model = model
    end

    def ids
      Set.new(Node.blocked_for(model.name).map(&:securable_id) - [0])
    end

  end
end
