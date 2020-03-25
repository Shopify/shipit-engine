# typed: false
class ImproveUsersIndexing < ActiveRecord::Migration[5.0]
  def change
    add_index :users, :updated_at
    add_index :users, :github_id
  end
end
