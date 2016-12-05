class AddIndexesOnDeliveries < ActiveRecord::Migration[5.0]
  def up
    change_column :deliveries, :status, :string, limit: 50
    change_column :deliveries, :event, :string, limit: 50
    add_index :deliveries, [:hook_id, :event, :status]
    add_index :deliveries, [:status, :event]
    add_index :deliveries, :created_at
  end

  def down
    change_column :deliveries, :status, :string, limit: 255
    change_column :deliveries, :event, :string, limit: 255
    remove_index :deliveries, [:hook_id, :event, :status]
    remove_index :deliveries, [:status, :event]
    remove_index :deliveries, :created_at
  end
end
