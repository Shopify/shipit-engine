class RemoveCommitStateAndTargetUrl < ActiveRecord::Migration
  def change
    remove_column :commits, :state
    remove_column :commits, :target_url
  end
end
