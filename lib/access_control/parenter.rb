require 'access_control/exceptions'
require 'access_control/node'

module AccessControl
  class Parenter

    attr_reader :record

    def initialize(record)
      raise InvalidInheritage unless record.class.
        respond_to?(:inherits_permissions_from)
      @record = record
    end

    def get
      p = record.class.inherits_permissions_from.inject(Set.new) do |p, assoc|
        p | Set.new([record.send(assoc)].flatten.compact)
      end
      p.any? ? p : Set.new([GlobalRecord.instance])
    end

  end
end
