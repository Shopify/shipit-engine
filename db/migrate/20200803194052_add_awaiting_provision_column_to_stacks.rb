class AddAwaitingProvisionColumnToStacks < ActiveRecord::Migration[6.0]
  def up
    add_column :stacks, :awaiting_provision, :boolean, null: false, default: false
    add_index :stacks, :awaiting_provision
  end

  def down
    remove_index :stacks, :awaiting_provision
    remove_column :stacks, :awaiting_provision
  end
end
