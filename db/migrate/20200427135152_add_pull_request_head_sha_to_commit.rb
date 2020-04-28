class AddPullRequestHeadShaToCommit < ActiveRecord::Migration[6.0]
  def change
    add_column :commits, :pull_request_head_sha, :string, limit: 40
  end
end
