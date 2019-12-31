class AddPerPrProvisioningOptInAndOutLabelsToRepositories < ActiveRecord::Migration[6.0]
  def change
    add_column :repositories, :provisioning_behavior, :integer, default: 0
    add_column :repositories, :provisioning_label_name, :string
  end
end
