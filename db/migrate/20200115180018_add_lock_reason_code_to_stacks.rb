class AddLockReasonCodeToStacks < ActiveRecord::Migration[6.0]
  def change
    add_column :stacks, :lock_reason_code, :string
    add_index :stacks, :lock_reason_code
  end
end
