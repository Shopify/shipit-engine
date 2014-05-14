class AddLockReasonToStack < ActiveRecord::Migration
  def change
    add_column :stacks, :lock_reason, :string
  end
end
