class CreateRecord < ActiveRecord::Migration
  def self.up
    create_table(:records, :force => true) do |t|
      t.integer :field
      # This field is named "name" to purposely match a field in the ac_roles
      # table.
      t.string :name
    end
  end

  def self.down
    drop_table :records
  end
end
