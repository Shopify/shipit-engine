class AddDeployedAtToStack < ActiveRecord::Migration[5.0]
  def up
    add_column :stacks, :deployed_at, :datetime
  end

  def down
    remove_column :stacks, :deployed_at
  end
end
