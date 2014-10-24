class AddDeploySpecToStack < ActiveRecord::Migration
  def change
    add_column :stacks, :cached_deploy_spec, :text
    remove_column :stacks, :supports_fetch_deployed_revision, :boolean
    remove_column :stacks, :supports_rollback, :boolean
  end
end
