class AddProvisionPrStacksFlagToRepositories < ActiveRecord::Migration[6.0]
  def change
    add_column :repositories, :review_stacks_enabled, :boolean, default: false
    add_column :repositories, :provisioning_behavior, :string, default: :allow_all
    add_column :repositories, :provisioning_label_name, :string
  end
end
