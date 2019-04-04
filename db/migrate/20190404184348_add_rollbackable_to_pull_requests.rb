class AddRollbackableToPullRequests < ActiveRecord::Migration[5.2]
  def change
    add_column :pull_requests, :rollbackable, :boolean
  end
end
