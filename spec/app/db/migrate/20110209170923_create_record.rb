class CreateRecord < ActiveRecord::Migration
  def self.up
    create_table(:records, :force => true) do |t|
      t.integer :field
    end
  end

  def self.down
    drop_table :records
  end
end
