require 'access_control/exceptions'
require 'access_control/node'
require 'access_control/behavior'

module AccessControl
  class Parenter

    def self.parents_of(record, associations = record.class.inherits_permissions_from)
      self.new(record, associations).get
    end

    attr_reader :record

    def initialize(record, associations = record.class.inherits_permissions_from)
      raise InvalidInheritage unless record.kind_of?(Inheritance)
      @record = record
      @parent_associations = associations
    end

    def get(default_to_global_record = true)
      parents = Util.flat_set(@parent_associations) do |association_name|
        @record.public_send(association_name)
      end

      parents.reject!(&:nil?)

      if parents.empty? && default_to_global_record
        Set[GlobalRecord.instance]
      else
        Set.new(parents)
      end
    end

  end
end
