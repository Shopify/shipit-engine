class AddLockLevelToStacks < ActiveRecord::Migration[5.2]
  def change
    add_column :stacks, :lock_level, :string
  end
end
