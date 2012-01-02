# vim: fdm=marker

class CreateAccessControl < ActiveRecord::Migration

  module Helper
    # Migration helper code {{{
    class << self
      def default_options
        @default_options ||= use_inno_db_and_set_charset? ?
          { :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' } : {}
      end

      def id_to_limit_8_sql(executor, table)
        case adapter
        when 'mysql'
          executor.execute(
            "ALTER TABLE `#{table}` CHANGE COLUMN `id` "\
            "`id` BIGINT NOT NULL AUTO_INCREMENT"
          )
        end
      end

      def add_constraints(executor, table, options)
        case adapter
        when 'mysql'
          options.each do |key, other|
            executor.execute("
              ALTER TABLE `#{table}`
                ADD CONSTRAINT `constraint_#{table}_on_#{key}`
                FOREIGN KEY (`#{key}`)
                REFERENCES `#{other}`(`id`)
                ON UPDATE CASCADE
                ON DELETE RESTRICT
            ")
          end
        end
      end

    private

      def use_inno_db_and_set_charset?
        adapter == 'mysql'
      end

      def adapter
        @adapter ||=
          begin
            adapter = ActiveRecord::Base.configurations[Rails.env]['adapter']
            if adapter == 'mysql' || adapter == 'mysql2'
              'mysql'
            else
              adapter
            end
          end
      end
    end
    # }}}
  end

  def self.up

    create_table(:ac_nodes, Helper.default_options) do |t|
      t.string  :securable_type, :limit => 40, :null => false
      t.integer :securable_id,   :limit => 8,   :null => false
      t.boolean :block, :default => false, :null => false
      t.integer :lock_version, :default => 0
    end
    Helper.id_to_limit_8_sql(self, :ac_nodes)
    add_index :ac_nodes, [:securable_type, :securable_id], :unique => true

    create_table(:ac_parents,
                 Helper.default_options.merge(:id => false)) do |t|
      t.integer :parent_id, :limit => 8, :null => false
      t.integer :child_id,  :limit => 8, :null => false
    end
    add_index :ac_parents, [:parent_id, :child_id], :unique => true
    Helper.add_constraints(self, :ac_parents, {
      :child_id  => :ac_nodes,
      :parent_id => :ac_nodes
    })

    # This table is a wrapper for users/groups/whatever.
    create_table(:ac_principals, Helper.default_options) do |t|
      t.string :subject_type, :limit => 40, :null => false
      t.integer :subject_id, :null => false
      t.integer :lock_version, :default => 0
    end
    add_index :ac_principals, [:subject_type, :subject_id], :unique => true

    create_table(:ac_roles, Helper.default_options) do |t|
      t.string :name, :limit => 40, :null => false
      t.string :title, :limit => 40
      t.string :description, :limit => 150
      t.boolean :local, :default => true, :null => false
      t.boolean :global, :default => true, :null => false
      t.integer :lock_version, :default => 0
    end
    add_index :ac_roles, :name, :unique => true

    create_table(:ac_security_policy_items, Helper.default_options) do |t|
      t.string :permission, :limit => 60, :null => false
      t.integer :role_id, :null => false
      t.integer :lock_version, :default => 0
    end
    add_index :ac_security_policy_items, [:permission, :role_id],
              :unique => true
    Helper.add_constraints(self, :ac_security_policy_items, {
      :role_id => :ac_roles
    })

    create_table(:ac_assignments, Helper.default_options) do |t|
      t.integer :node_id, :limit => 8, :null => false
      t.integer :principal_id, :null => false
      t.integer :role_id, :null => false
      t.integer :lock_version, :default => 0
    end
    add_index(
      :ac_assignments,
      [:principal_id, :node_id, :role_id],
      :unique => true,
      :name => 'index_on_principal_id_and_node_id_and_role_id'
    )
    Helper.add_constraints(self, :ac_assignments, {
      :node_id      => :ac_nodes,
      :role_id      => :ac_roles,
      :principal_id => :ac_principals
    })
  end

  def self.down
    drop_table :ac_assignments
    drop_table :ac_security_policy_items
    drop_table :ac_roles
    drop_table :ac_principals
    drop_table :ac_parents
    drop_table :ac_nodes
  end
end
