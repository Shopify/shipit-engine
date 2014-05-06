class AddSecretToWebhooks < ActiveRecord::Migration
  def change
    add_column :webhooks, :secret, :string
  end
end
