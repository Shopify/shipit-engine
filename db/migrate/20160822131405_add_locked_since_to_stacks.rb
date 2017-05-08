class AddLockedSinceToStacks < ActiveRecord::Migration[4.2]
  def change
    add_column :stacks, :locked_since, :datetime, null: true
  end
end
