class AddDeployUrlToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :deploy_url, :string
  end
end
