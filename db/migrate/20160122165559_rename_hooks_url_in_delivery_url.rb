class RenameHooksUrlInDeliveryUrl < ActiveRecord::Migration
  def change
    rename_column :hooks, :url, :delivery_url
  end
end
