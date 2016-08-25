class EnsureUniquenessOnAcAssignments < ActiveRecord::Migration
  def self.up
    remove_index :ac_assignments, [:principal_id, :role_id, :node_id]
    add_index :ac_assignments, [:principal_id, :role_id, :node_id], unique: true
  end

  def self.down
    remove_index :ac_assignments, [:principal_id, :role_id, :node_id]
    add_index :ac_assignments, [:principal_id, :role_id, :node_id]
  end
end
