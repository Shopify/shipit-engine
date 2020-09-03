class AddProvisionPrStacksFlagToRepositories < ActiveRecord::Migration[6.0]
  def change
    add_column :repositories, :review_stacks_enabled, :boolean, default: false
  end
end
