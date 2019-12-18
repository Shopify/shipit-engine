class AddProvisionPrStacksFlagToRepositories < ActiveRecord::Migration[6.0]
  def change
    add_column :repositories, :provision_pr_stacks, :boolean, default: false
  end
end
