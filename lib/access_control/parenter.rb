require 'access_control/exceptions'
require 'access_control/node'
require 'access_control/behavior'

module AccessControl
  class Parenter

    def self.parents_of(*args)
      self.new(*args).parent_records
    end

    def self.parent_nodes_of(*args)
      self.new(*args).parent_nodes
    end

    def self.ancestor_records_of(*args)
      self.new(*args).ancestor_records
    end

    attr_reader :record

    def initialize(record, associations = nil)
      raise InvalidInheritage unless Inheritance.recognizes?(record)

      associations ||= record.class.inherits_permissions_from

      @record = record
      @parent_associations = associations
    end

    def parent_records
      parents = Util.compact_flat_set(@parent_associations) do |association_name|
        @record.public_send(association_name)
      end

      if parents.empty?
        Set[GlobalRecord.instance]
      else
        Set.new(parents)
      end
    end

    def parent_nodes
      Util.compact_flat_set(parent_records) do |parent|
        AccessControl::Node(parent)
      end
    end

    def ancestor_records
      Util.flat_set(parent_records) do |parent|
        if Inheritance.recognizes?(parent)
          Parenter.ancestor_records_of(parent) << parent
        else
          parent
        end
      end
    end
  end
end
