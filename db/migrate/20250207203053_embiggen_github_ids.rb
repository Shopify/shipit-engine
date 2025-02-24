class EmbiggenGithubIds < ActiveRecord::Migration[7.2]
  def change
    change_column(:commit_deployments, :github_id, :bigint)
    change_column(:github_hooks, :github_id, :bigint)
    change_column(:teams, :github_id, :bigint)
    change_column(:users, :github_id, :bigint)
  end
end
