class PredictiveBranchCommitSha < ActiveRecord::Migration[6.0]

  def change
    add_column :predictive_branches, :until_commit_sha, :string, limit: 100, null: true
  end

end

