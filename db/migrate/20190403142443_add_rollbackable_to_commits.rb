class AddRollbackableToCommits < ActiveRecord::Migration[5.2]
  def change
    add_column :commits, :rollbackable, :boolean
  end
end
