class CreateAccessControl < ActiveRecord::Migration

  def self.up

    create_table :ac_nodes,
                 :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.string :securable_type, :limit => 40, :null => false
      t.integer :securable_id, :limit => 8, :null => false
      t.boolean :block, :default => false, :null => false
    end
    execute "
      ALTER TABLE `ac_nodes`
      CHANGE COLUMN `id` `id` BIGINT DEFAULT NULL AUTO_INCREMENT
    "
    add_index :ac_nodes, [:securable_type, :securable_id], :unique => true

    create_table :ac_parents,
                 :id => false,
                 :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer :node_id, :limit => 8, :null => false
      t.integer :parent_id, :limit => 8, :null => false
    end
    add_index :ac_parents, [:node_id, :parent_id], :unique => true
    execute "
      ALTER TABLE `ac_parents`
        ADD CONSTRAINT `constraint_ac_parents_on_node_id`
        FOREIGN KEY (`node_id`)
        REFERENCES `ac_nodes`(`id`)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    "
    execute "
      ALTER TABLE `ac_parents`
        ADD CONSTRAINT `constraint_ac_parents_on_parent_id`
        FOREIGN KEY (`parent_id`)
        REFERENCES `ac_nodes`(`id`)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    "

    create_table :ac_paths,
                 :id => false,
                 :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer :ancestor_id, :limit => 8, :null => false
      t.integer :descendant_id, :limit => 8, :null => false
    end
    add_index :ac_paths, [:ancestor_id, :descendant_id], :unique => true
    execute "
      ALTER TABLE `ac_paths`
        ADD CONSTRAINT `constraint_ac_paths_on_ancestor_id`
        FOREIGN KEY (`ancestor_id`)
        REFERENCES `ac_nodes`(`id`)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    "
    execute "
      ALTER TABLE `ac_paths`
        ADD CONSTRAINT `constraint_ac_paths_on_descendant_id`
        FOREIGN KEY (`descendant_id`)
        REFERENCES `ac_nodes`(`id`)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    "

    # This table is a wrapper for users/groups/whatever.
    create_table :ac_principals,
                 :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.string :subject_type, :limit => 40, :null => false
      t.integer :subject_id, :null => false
    end
    add_index :ac_principals, [:subject_type, :subject_id], :unique => true

    create_table :ac_roles,
                 :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.string :name, :limit => 40, :null => false
      t.string :title, :limit => 40
      t.string :description, :limit => 100
    end
    add_index :ac_roles, :name, :unique => true

    create_table :ac_security_policy_items,
                 :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.string :permission_name, :limit => 40, :null => false
      t.integer :role_id, :null => false
    end
    add_index :ac_security_policy_items, [:permission_name, :role_id],
              :unique => true
    execute "
      ALTER TABLE `ac_security_policy_items`
        ADD CONSTRAINT `constraint_ac_security_policy_items_on_role_id`
        FOREIGN KEY (`role_id`)
        REFERENCES `ac_roles`(`id`)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    "

    create_table :ac_assignments,
                 :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' do |t|
      t.integer :node_id, :limit => 8, :null => false
      t.integer :principal_id, :null => false
      t.integer :role_id, :null => false
    end
    add_index(
      :ac_assignments,
      [:principal_id, :node_id, :role_id],
      :unique => true,
      :name => 'index_on_principal_id_and_node_id_and_role_id'
    )
    execute "
      ALTER TABLE `ac_assignments`
        ADD CONSTRAINT `constraint_ac_assignments_on_node_id`
        FOREIGN KEY (`node_id`)
        REFERENCES `ac_nodes`(`id`)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    "
    execute "
      ALTER TABLE `ac_assignments`
        ADD CONSTRAINT `constraint_ac_assignments_on_principal_id`
        FOREIGN KEY (`principal_id`)
        REFERENCES `ac_principals`(`id`)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    "
    execute "
      ALTER TABLE `ac_assignments`
        ADD CONSTRAINT `constraint_ac_assignments_on_role_id`
        FOREIGN KEY (`role_id`)
        REFERENCES `ac_roles`(`id`)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    "
  end

  def self.down
    drop_table :ac_assignments
    drop_table :ac_security_policy_items
    drop_table :ac_roles
    drop_table :ac_principals
    drop_table :ac_paths
    drop_table :ac_parents
    drop_table :ac_nodes
  end
end
