class AddLockedToCommits < ActiveRecord::Migration[5.0]
  def change
    add_column :commits, :locked, :boolean, default: false, null: false
  end
end
