module AccessControl::Model
  class Assignment < ActiveRecord::Base
    set_table_name :ac_assignments
    belongs_to :node, :class_name => 'AccessControl::Model::Node'
    belongs_to :principal, :class_name => 'AccessControl::Model::Principal'
    belongs_to :role, :class_name => 'AccessControl::Model::Role'
    def securable?
      false
    end
  end
end
