class ReindexDeliveries < ActiveRecord::Migration[5.1]
  def change
    add_index :deliveries, [:hook_id, :status]
    remove_index :deliveries, [:created_at]
    remove_index :deliveries, [:status, :event]
  end
end
