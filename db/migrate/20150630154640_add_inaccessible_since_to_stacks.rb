class AddInaccessibleSinceToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :inaccessible_since, :datetime, default: nil
  end
end
