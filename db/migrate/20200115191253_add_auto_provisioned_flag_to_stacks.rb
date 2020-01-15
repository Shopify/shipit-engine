class AddAutoProvisionedFlagToStacks < ActiveRecord::Migration[6.0]
  def change
    add_column :stacks, :auto_provisioned, :boolean, default: false
    add_index :stacks, :auto_provisioned
  end
end
