class AddStackUndeployedCommitsCount < ActiveRecord::Migration
  def up
    add_column :stacks, :undeployed_commits_count, :integer, default: 0, null: false
  end

  def down
    remove_column :stacks, :undeployed_commits_count
  end
end
