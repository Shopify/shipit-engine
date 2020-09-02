# frozen_string_literal: true

class RemoveStacksLockReasonCode < ActiveRecord::Migration[6.0]
  def change
    remove_index :stacks, :lock_reason_code
    remove_column :stacks, :lock_reason_code, :string
  end
end
