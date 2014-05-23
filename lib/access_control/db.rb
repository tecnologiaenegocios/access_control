require 'active_record'
require 'sequel'

module AccessControl
  class << self
    def ac_parents
      db[:ac_parents]
    end

    def ac_nodes
      db[:ac_nodes]
    end

    def ac_effective_assignments
      db[:ac_effective_assignments]
    end

    def db
      @sequel_db
    end

    def db= db
      @sequel_db = db
    end

    def transaction
      ActiveRecord::Base.transaction do
        @sequel_db.transaction do
          yield
        end
      end
    end
  end
end
