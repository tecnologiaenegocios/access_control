class RenameAcAssignmentsToLegacyAcAssignments < ActiveRecord::Migration
  def self.up
    rename_table(:ac_assignments, :ac_legacy_assignments)
  end

  def self.down
    rename_table(:ac_legacy_assignments, :ac_assignments)
  end
end
