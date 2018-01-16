class ChangeIndexesOnAcParents < ActiveRecord::Migration
  extend AccessControl::MigrationHelper

  def self.up
    execute("ALTER TABLE ac_parents DROP FOREIGN KEY constraint_ac_parents_on_parent_id")
    execute("ALTER TABLE ac_parents DROP FOREIGN KEY constraint_ac_parents_on_child_id")
    remove_index(:ac_parents, [:parent_id, :child_id])
    remove_index(:ac_parents, [:child_id])
    add_index(:ac_parents, [:child_id, :parent_id], unique: true)
    add_index(:ac_parents, [:parent_id])
    add_constraints(
      :ac_parents,
      parent_id: { parent: :ac_nodes },
      child_id: { parent: :ac_nodes }
    )
  end

  def self.down
    execute("ALTER TABLE ac_parents DROP FOREIGN KEY constraint_ac_parents_on_parent_id")
    execute("ALTER TABLE ac_parents DROP FOREIGN KEY constraint_ac_parents_on_child_id")
    remove_index(:ac_parents, [:parent_id])
    remove_index(:ac_parents, [:child_id, :parent_id])
    add_index(:ac_parents, [:parent_id, :child_id], unique: true)
    add_index(:ac_parents, [:child_id])
    add_constraints(
      :ac_parents,
      parent_id: { parent: :ac_nodes },
      child_id: { parent: :ac_nodes }
    )
  end
end
