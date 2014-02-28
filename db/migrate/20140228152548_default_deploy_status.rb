class DefaultDeployStatus < ActiveRecord::Migration
  def change
    Deploy.update_all(status: 'pending')
    change_column :deploys, :status, :string, default: 'pending', null: false
  end
end
