class AddIndexToAcAssignments < ActiveRecord::Migration
  def self.up
    add_index :ac_assignments, [:principal_id, :role_id, :node_id]
  end

  def self.down
    remove_index :ac_assignments, [:principal_id, :role_id, :node_id]
  end
end
