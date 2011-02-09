class CreateRecord < ActiveRecord::Migration
  def self.up
    create_table(:records, :force => true) {}
  end

  def self.down
    drop_table :records
  end
end
