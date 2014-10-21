class AddCommitStats < ActiveRecord::Migration
  def change
    add_column :commits, :additions, :integer, default: 0
    add_column :commits, :deletions, :integer, default: 0
  end
end
