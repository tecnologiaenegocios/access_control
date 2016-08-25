class DropParentIdOnAcAssignments < ActiveRecord::Migration
  def self.up
    remove_column(:ac_assignments, :parent_id)
  end

  def self.down
    add_column(:ac_assignments, :parent_id, :integer, limit: 8, before: :role_id)
  end
end
