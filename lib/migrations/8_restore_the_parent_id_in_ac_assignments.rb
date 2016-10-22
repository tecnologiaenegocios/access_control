class RestoreTheParentIdInAcAssignments < ActiveRecord::Migration
  def self.up
    add_column(:ac_assignments, :parent_id, :integer, limit: 8)

    add_index :ac_assignments, :parent_id

    execute(
      "ALTER TABLE ac_assignments "\
        "ADD CONSTRAINT constraint_ac_assignments_on_parent_id "\
        "FOREIGN KEY (parent_id) "\
        "REFERENCES ac_assignments(id) "\
        "ON UPDATE CASCADE "\
        "ON DELETE CASCADE"
    )
  end

  def self.down
    execute(
      "ALTER TABLE ac_assignments "\
        "DROP FOREIGN KEY constraint_ac_assignments_on_parent_id"
    )

    remove_index(:ac_assignments, [:parent_id])

    remove_column(:ac_assignments, :parent_id)
  end
end
