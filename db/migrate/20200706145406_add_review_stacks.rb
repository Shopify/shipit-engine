class AddReviewStacks < ActiveRecord::Migration[6.0]
  def up
    add_column :stacks, :type, :string, default: "Shipit::Stack"
    add_index :stacks, :type
  end

  def down
    remove_index :stacks, :type
    remove_column :stacks, :type
  end
end
