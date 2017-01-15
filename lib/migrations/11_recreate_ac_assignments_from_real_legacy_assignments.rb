class RecreateAcAssignmentsFromRealLegacyAssignments < ActiveRecord::Migration
  extend AccessControl::MigrationHelper

  def self.up
    create_table(:ac_assignments, default_options.merge(force: true)) do |t|
      t.integer :role_id,             null: false
      t.integer :principal_id,        null: false
      t.integer :node_id,   limit: 8, null: false
    end
    id_to_limit_8(:ac_assignments)
    add_index :ac_assignments, :role_id,
              name: 'index_1_oc_assignments_on_role_id'
    add_index :ac_assignments, :principal_id,
              name: 'index_1_oc_assignments_on_principal_id'
    add_index :ac_assignments, :node_id,
              name: 'index_1_oc_assignments_on_node_id'
    add_index :ac_assignments, [:principal_id, :role_id, :node_id],
              unique: true,
              name: 'index_1_ac_assignments_on_principal_id_and_role_id_and_node_id'
    add_constraints(
      :ac_assignments,
      node_id: { parent: :ac_nodes, name: 'constraint_1_ac_assignments_on_node_id' },
      role_id: { parent: :ac_roles, name: 'constraint_1_ac_assignments_on_role_id' },
      principal_id: { parent: :ac_principals, name: 'constraint_1_ac_assignments_on_principal_id' }
    )

    db_config = ActiveRecord::Base.configurations[Rails.env].dup
    db = Sequel.connect(db_config)

    sql = db[:ac_legacy_assignments]
      .filter(parent_id: nil)
      .distinct.select(:node_id, :role_id, :principal_id)
      .sql

    execute("INSERT INTO ac_assignments (node_id, role_id, principal_id) #{sql}")
  end

  def self.down
    drop_table(:ac_assignments)
  end
end
