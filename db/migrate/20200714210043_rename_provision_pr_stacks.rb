class RenameProvisionPrStacks < ActiveRecord::Migration[6.0]
  def change
    rename_column :repositories, :provision_pr_stacks, :review_stacks_enabled
  end
end
