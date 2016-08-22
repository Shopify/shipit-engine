class AddLockedSinceToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :locked_since, :datetime, null: true
  end
end
