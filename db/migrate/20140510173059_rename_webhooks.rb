class RenameWebhooks < ActiveRecord::Migration
  def change
    rename_table :webhooks, :remote_webhooks
  end
end
