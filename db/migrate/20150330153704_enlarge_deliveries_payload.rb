class EnlargeDeliveriesPayload < ActiveRecord::Migration
  def change
    change_column :deliveries, :payload, :text, limit: 16.megabytes, null: false
  end
end
