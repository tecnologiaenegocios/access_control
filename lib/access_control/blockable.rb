module AccessControl
  class Blockable

    attr_reader :orm

    def initialize(orm)
      @orm = orm
    end

    def ids
      Set.new(Node.blocked_for(orm.name).
              select_values_of_column(:securable_id) - [0])
    end

  end
end
