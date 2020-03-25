# typed: true
class AddRepositoryReferenceToStacks < ActiveRecord::Migration[6.0]
  def up
    change_table(:stacks) do |t|
      t.references :repository
    end
  end

  def down
    change_column :stacks, :repo_name, :string, null: false
    change_column :stacks, :repo_owner, :string, null: false
    change_table(:stacks) do |t|
      t.remove_references :repository
    end
  end
end
