class AddBaseInfoToPullRequest < ActiveRecord::Migration[5.1]
  def change
    add_column :pull_requests, :base_ref, :string, limit: 1024
    add_column :pull_requests, :base_commit_id, :integer
    add_foreign_key :pull_requests, :commits, column: :base_commit_id
  end
end
