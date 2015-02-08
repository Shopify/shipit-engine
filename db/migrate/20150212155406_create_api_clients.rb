class CreateApiClients < ActiveRecord::Migration
  def change
    create_table :api_clients do |t|
      t.text :permissions
      t.references :creator, index: true

      t.timestamps null: false
    end
  end
end
