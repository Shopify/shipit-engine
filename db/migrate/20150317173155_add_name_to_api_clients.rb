class AddNameToApiClients < ActiveRecord::Migration
  def change
    add_column :api_clients, :name, :string, default: ''
  end
end
