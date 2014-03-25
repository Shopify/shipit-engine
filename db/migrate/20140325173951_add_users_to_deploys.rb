class AddUsersToDeploys < ActiveRecord::Migration
  def change
    add_column :deploys, :user_name, :string, null: false, default: 'Anonymous'
    add_column :deploys, :user_email, :string, null: false, default: 'anonymous@example.com'
    add_column :deploys, :user_id, :integer, null: true
    add_index :deploys, :user_id
  end
end
