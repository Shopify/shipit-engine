class RemoveRepositoryInformationFromStacks < ActiveRecord::Migration[6.0]
  def up
    change_column :stacks, :repository_id, :integer, null: false
    change_table(:stacks) do |t|
      t.remove_index ["repo_owner", "repo_name", "environment"]
      t.remove :repo_owner
      t.remove :repo_name
      t.index ["repository_id", "environment"], name: "stack_unicity", unique: true
    end
  end

  def down
    change_table(:stacks) do |t|
      t.column :repo_name, :string, limit: 100
      t.column :repo_owner, :string, limit: 39
      t.remove_index ["repository_id", "environment"]
      t.index ["repo_owner", "repo_name", "environment"], name: "stack_unicity", unique: true
    end
  end
end
