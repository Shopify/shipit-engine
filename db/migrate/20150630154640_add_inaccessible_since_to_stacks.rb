# typed: false
class AddInaccessibleSinceToStacks < ActiveRecord::Migration[4.2]
  def change
    add_column :stacks, :inaccessible_since, :datetime, default: nil
  end
end
