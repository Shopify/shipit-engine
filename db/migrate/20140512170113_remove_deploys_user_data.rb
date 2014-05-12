class RemoveDeploysUserData < ActiveRecord::Migration
  def change
    remove_column :deploys, :user_email
    remove_column :deploys, :user_name
  end
end
