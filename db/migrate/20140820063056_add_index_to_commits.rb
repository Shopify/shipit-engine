class AddIndexToCommits < ActiveRecord::Migration
  def change
    add_index :commits, :created_at, :name => "index_commits_on_created_at"
  end
end
