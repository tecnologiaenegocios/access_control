# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20111206183515) do

  create_table "ac_assignments", :force => true do |t|
    t.integer "node_id",      :limit => 8,                :null => false
    t.integer "principal_id",                             :null => false
    t.integer "role_id",                                  :null => false
    t.integer "lock_version",              :default => 0
  end

  add_index "ac_assignments", ["node_id"], :name => "constraint_ac_assignments_on_node_id"
  add_index "ac_assignments", ["principal_id", "node_id", "role_id"], :name => "index_on_principal_id_and_node_id_and_role_id", :unique => true
  add_index "ac_assignments", ["role_id"], :name => "constraint_ac_assignments_on_role_id"

  create_table "ac_nodes", :force => true do |t|
    t.string  "securable_type", :limit => 40,                    :null => false
    t.integer "securable_id",   :limit => 8,                     :null => false
    t.boolean "block",                        :default => false, :null => false
    t.integer "lock_version",                 :default => 0
  end

  add_index "ac_nodes", ["securable_type", "securable_id"], :name => "index_ac_nodes_on_securable_type_and_securable_id", :unique => true

  create_table "ac_principals", :force => true do |t|
    t.string  "subject_type", :limit => 40,                :null => false
    t.integer "subject_id",                                :null => false
    t.integer "lock_version",               :default => 0
  end

  add_index "ac_principals", ["subject_type", "subject_id"], :name => "index_ac_principals_on_subject_type_and_subject_id", :unique => true

  create_table "ac_roles", :force => true do |t|
    t.string  "name",         :limit => 40,                    :null => false
    t.string  "title",        :limit => 40
    t.string  "description",  :limit => 150
    t.boolean "local",                       :default => true, :null => false
    t.boolean "global",                      :default => true, :null => false
    t.integer "lock_version",                :default => 0
  end

  add_index "ac_roles", ["name"], :name => "index_ac_roles_on_name", :unique => true

  create_table "ac_security_policy_items", :force => true do |t|
    t.string  "permission",   :limit => 60,                :null => false
    t.integer "role_id",                                   :null => false
    t.integer "lock_version",               :default => 0
  end

  add_index "ac_security_policy_items", ["permission", "role_id"], :name => "index_ac_security_policy_items_on_permission_and_role_id", :unique => true
  add_index "ac_security_policy_items", ["role_id"], :name => "constraint_ac_security_policy_items_on_role_id"

  create_table "records", :force => true do |t|
    t.integer "field"
    t.string  "name"
    t.integer "record_id"
  end

  create_table "records_records", :id => false, :force => true do |t|
    t.integer "from_id"
    t.integer "to_id"
  end

end
