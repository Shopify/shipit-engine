class RenameHooksUrlInDeliveryUrl < ActiveRecord::Migration[4.2]
  def change
    rename_column :hooks, :url, :delivery_url
  end
end
