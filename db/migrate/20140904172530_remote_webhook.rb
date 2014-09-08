class RemoteWebhook < ActiveRecord::Migration
  def change
    create_table :remote_webhooks do |t|
      t.references :stack, index: true, null: false
      t.string :endpoint
      t.string :action

      t.timestamps
    end

  end
end
