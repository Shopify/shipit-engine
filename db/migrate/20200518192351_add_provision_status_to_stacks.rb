class AddProvisionStatusToStacks < ActiveRecord::Migration[6.0]
  def up
    add_column :stacks, :provision_status, :string, null: false, default: :deprovisioned
    add_index :stacks, :provision_status
  end

  def down
    remove_index :stacks, :provision_status
    remove_column :stacks, :provision_status
  end
end
