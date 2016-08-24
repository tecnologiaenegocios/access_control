class DropNonRealAssignments < ActiveRecord::Migration
  def self.up
    execute("DELETE FROM ac_assignments WHERE parent_id IS NOT NULL")
    execute(
      "ALTER TABLE ac_assignments "\
        "DROP FOREIGN KEY constraint_ac_assignments_on_parent_id"
    )
    remove_index(:ac_assignments, [:parent_id])
  end

  def self.down
    add_index :ac_assignments, :parent_id
    execute(
      "ALTER TABLE ac_assignments "\
        "ADD CONSTRAINT constraint_ac_assignments_on_parent_id "\
        "FOREIGN KEY (parent_id) "\
        "REFERENCES ac_assignments(id) "\
        "ON UPDATE CASCADE "\
        "ON DELETE CASCADE"
    )
    # Data is not easily recoverable.
  end
end
