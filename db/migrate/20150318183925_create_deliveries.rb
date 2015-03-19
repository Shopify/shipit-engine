class CreateDeliveries < ActiveRecord::Migration
  def change
    create_table :deliveries do |t|
      t.references :hook, null: false

      t.string :status, null: false, default: 'pending'

      t.string :url, limit: 4096, null: false
      t.string :content_type, null: false
      t.string :event, null: false
      t.text :payload, null: false

      t.integer :response_code
      t.text :response_headers
      t.text :response_body

      t.timestamp :delivered_at, null: true
      t.timestamps null: false
    end
  end
end
