module AccessControl
  class Assignment < ActiveRecord::Base
    set_table_name :ac_assignments
    belongs_to :node, :class_name => 'AccessControl::Node'
    belongs_to :principal, :class_name => 'AccessControl::Principal'
    belongs_to :role, :class_name => 'AccessControl::Role'
    def self.securable?
      false
    end
  end
end
