class EnforceGithubHooksUnicity < ActiveRecord::Migration
  def change
    add_index :github_hooks, %i(stack_id event), unique: true
    add_column :github_hooks, :api_url, :string
  end
end
