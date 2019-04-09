class AddRollbackableToCommits < ActiveRecord::Migration[5.2]
  def change
    add_column :commits, :unsafe_to_rollback, :boolean
  end
end
