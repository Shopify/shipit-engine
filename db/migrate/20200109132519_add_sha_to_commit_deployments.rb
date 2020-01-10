class AddShaToCommitDeployments < ActiveRecord::Migration[6.0]
  def change
    add_column :commit_deployments, :sha, :string, limit: 40
  end
end
