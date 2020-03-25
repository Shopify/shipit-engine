# typed: false
class AddEstimatedDeployDurationToStacks < ActiveRecord::Migration[4.2]
  def change
    add_column :stacks, :estimated_deploy_duration, :integer, null: false, default: 1
  end
end
