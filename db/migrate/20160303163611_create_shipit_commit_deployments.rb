class CreateShipitCommitDeployments < ActiveRecord::Migration
  def change
    create_table :commit_deployments do |t|
      t.references :commit, foreign_key: true
      t.references :task, index: true, foreign_key: true
      t.integer :github_id, null: true
      t.string :api_url, null: true

      t.timestamps null: false

      t.index %i(commit_id task_id), unique: true
    end
  end
end
