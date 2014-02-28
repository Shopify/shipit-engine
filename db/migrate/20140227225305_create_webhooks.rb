class CreateWebhooks < ActiveRecord::Migration
  def change
    create_table :webhooks do |t|
      t.references :stack, null: false
      t.integer :github_id
      t.string :event
      t.timestamps
    end
  end
end
