class GithubHookSti < ActiveRecord::Migration
  def up
    change_column :github_hooks, :stack_id, :integer, null: true, default: nil
    add_column :github_hooks, :type, :string
    add_column :github_hooks, :organization, :string
    add_index :github_hooks, %i(organization event), unique: true

    connection.execute %(UPDATE github_hooks SET type = 'GithubHook::Repo')
  end

  def down
    remove_index :github_hooks, %i(organization event)

    change_column :github_hooks, :stack_id, :integer, null: false
    remove_column :github_hooks, :type
    remove_column :github_hooks, :organization
  end
end
