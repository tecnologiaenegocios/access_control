require 'access_control/db'
require 'access_control/node'

module AccessControl
  class MethodInheritance

    attr_reader :model_class, :method_name
    def initialize(model_class, method_name)
      @model_class = model_class
      @method_name = method_name
    end

    def parent_nodes_ids(records = model_class.all)
      parent_records_of(records).map do |parent_record|
        AccessControl::Node(parent_record).id
      end
    end

    def parent_nodes_dataset(records = model_class.all)
      Node::Persistent.for_securables parent_records_of(records)
    end

  private

    def parent_records_of(records)
      records.map do |record|
        record.send(method_name)
      end
    end

  end
end
