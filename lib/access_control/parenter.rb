require 'access_control/exceptions'
require 'access_control/node'
require 'access_control/behavior'

module AccessControl
  class Parenter

    attr_reader :record

    def initialize(record)
      raise InvalidInheritage unless record.class.
        respond_to?(:inherits_permissions_from)
      @record = record
    end

    def get(default_to_global_node = true)
      parent_associations = record.class.inherits_permissions_from

      parents = parent_associations.flat_map do |assoc|
        record.public_send(assoc) || []
      end

      if parents.empty? && default_to_global_node
        Set[GlobalRecord.instance]
      else
        Set.new(parents)
      end
    end

  end
end
