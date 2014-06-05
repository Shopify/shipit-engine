class AddCdOptionToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :continuous_deployment, :boolean, default: false
  end
end
