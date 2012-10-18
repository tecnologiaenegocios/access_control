class CreateStiRecord < ActiveRecord::Migration
  def self.up
    create_table(:sti_records, :force => true) do |t|
      t.string :name
      t.string :type
    end
  end

  def self.down
    drop_table :sti_records
  end
end
