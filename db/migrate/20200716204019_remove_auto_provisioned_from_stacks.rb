class RemoveAutoProvisionedFromStacks < ActiveRecord::Migration[6.0]
  def change
    remove_column :stacks, :auto_provisioned
  end
end
