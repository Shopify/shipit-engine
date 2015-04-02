class AddStackIdToApiClients < ActiveRecord::Migration
  def change
    add_column :api_clients, :stack_id, :integer
  end
end
