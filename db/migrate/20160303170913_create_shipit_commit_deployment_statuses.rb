# typed: false
class CreateShipitCommitDeploymentStatuses < ActiveRecord::Migration[4.2]
  def change
    create_table :commit_deployment_statuses do |t|
      t.references :commit_deployment, index: true, foreign_key: true
      t.string :status
      t.integer :github_id
      t.string :api_url

      t.timestamps null: false
    end
  end
end
