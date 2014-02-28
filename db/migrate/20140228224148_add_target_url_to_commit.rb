class AddTargetUrlToCommit < ActiveRecord::Migration
  def change
    add_column :commits, :target_url, :string
  end
end
