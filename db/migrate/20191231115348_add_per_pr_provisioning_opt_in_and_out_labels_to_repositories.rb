class AddPerPrProvisioningOptInAndOutLabelsToRepositories < ActiveRecord::Migration[6.0]
  def change
    add_column :repositories, :provisioning_behavior, :string, default: :allow_all
    add_column :repositories, :provisioning_label_name, :string
  end
end
