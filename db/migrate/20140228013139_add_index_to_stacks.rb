class AddIndexToStacks < ActiveRecord::Migration
  def change
    add_index :stacks, [:repo_owner, :repo_name, :environment], :unique => true, :name => "stack_unicity"
  end
end
