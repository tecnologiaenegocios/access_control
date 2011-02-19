class CreateRecord < ActiveRecord::Migration
  def self.up
    create_table(:records, :force => true) do |t|
      t.integer :field
      # This field is named "name" to purposely match a field in the ac_roles
      # table.
      t.string :name
      t.integer :record_id
    end
    create_table(:records_records, :id => false, :force => true) do |t|
      t.integer :from_id
      t.integer :to_id
    end
  end

  def self.down
    drop_table :records_records
    drop_table :records
  end
end
