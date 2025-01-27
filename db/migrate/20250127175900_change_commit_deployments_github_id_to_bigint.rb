class ChangeCommitDeploymentsGithubIdToBigint < ActiveRecord::Migration[7.2]
  def change
    change_column :commit_deployments, :github_id, :bigint
  end
end
