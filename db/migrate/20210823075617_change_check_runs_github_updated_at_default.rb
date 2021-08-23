class ChangeCheckRunsGithubUpdatedAtDefault < ActiveRecord::Migration[6.1]
  def change
    change_column_default :check_runs, :github_updated_at, nil
  end
end
