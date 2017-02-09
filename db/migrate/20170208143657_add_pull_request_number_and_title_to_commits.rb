class AddPullRequestNumberAndTitleToCommits < ActiveRecord::Migration[5.0]
  def change
    add_column :commits, :pull_request_number, :integer, null: true
    add_column :commits, :pull_request_title, :string, limit: 1024, null: true
    add_column :commits, :pull_request_id, :integer, null: true, index: true
  end
end
