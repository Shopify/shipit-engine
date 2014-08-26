class AddDeploySpecRecordsToStack < ActiveRecord::Migration
  def change
    add_column :stacks, :supports_fetch_deployed_revision, :boolean, default: false, null: false
    add_column :stacks, :supports_rollback, :boolean, default: false, null: false
  end
end
