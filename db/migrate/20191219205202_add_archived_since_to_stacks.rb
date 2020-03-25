# typed: true
class AddArchivedSinceToStacks < ActiveRecord::Migration[6.0]
  def change
    add_column :stacks, :archived_since, :datetime
    add_index :stacks, :archived_since
  end
end
