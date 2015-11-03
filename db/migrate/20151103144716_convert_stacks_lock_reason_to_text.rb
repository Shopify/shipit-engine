class ConvertStacksLockReasonToText < ActiveRecord::Migration
  def change
    change_column :stacks, :lock_reason, :string, limit: 4096
  end
end
