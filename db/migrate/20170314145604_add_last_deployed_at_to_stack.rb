# typed: false
class AddLastDeployedAtToStack < ActiveRecord::Migration[5.0]
  def up
    add_column :stacks, :last_deployed_at, :datetime
  end

  def down
    remove_column :stacks, :last_deployed_at
  end
end
