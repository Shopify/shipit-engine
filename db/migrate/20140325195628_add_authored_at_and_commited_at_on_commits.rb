class AddAuthoredAtAndCommitedAtOnCommits < ActiveRecord::Migration
  def change
    add_column :commits, :authored_at, :datetime
    add_column :commits, :committed_at, :datetime
    Commit.where(authored_at: nil).update_all('authored_at = created_at')
    Commit.where(committed_at: nil).update_all('committed_at = created_at')
    change_column :commits, :authored_at, :datetime, null: false
    change_column :commits, :committed_at, :datetime, null: false
  end
end
