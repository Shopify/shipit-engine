class AddGithubUpdatedAtToCheckRuns < ActiveRecord::Migration[6.1]
  def change
    add_column :check_runs, :github_updated_at, :datetime, default: 0
  end
end
