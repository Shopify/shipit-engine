class ChangeCommitDeploymentStatusesGithubIdToBigInt < ActiveRecord::Migration[7.0]
  def change
    change_column :commit_deployment_statuses, :github_id, :bigint
  end
end
