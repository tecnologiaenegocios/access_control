module AccessControl
  class Assignment < ActiveRecord::Base
    set_table_name :ac_assignments
    belongs_to :node, :class_name => 'AccessControl::Node'
    belongs_to :principal, :class_name => 'AccessControl::Principal'
    belongs_to :role, :class_name => 'AccessControl::Role'
    def self.securable?
      false
    end

    def self.items_for_management(node, roles)
      all(
        :conditions => {:node_id => node.id, :role_id => roles.map(&:id)}
      ).group_by{|a| a.principal_id}.inject({}) do |r, (p_id, assigns)|
        r[p_id] = roles.map do |role|
          if assignment = assigns.detect{|a| a.role_id == role.id}
            next assignment
          end
          Assignment.new(:role_id => role.id, :node_id => node.id,
                         :principal_id => p_id)
        end
        r
      end
    end
  end
end
