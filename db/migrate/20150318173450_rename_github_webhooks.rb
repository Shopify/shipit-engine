class RenameGithubWebhooks < ActiveRecord::Migration
  def change
    rename_table(:webhooks, :github_hooks)
  end
end
