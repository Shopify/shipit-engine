class AddDetachedToCommits < ActiveRecord::Migration
  def change
    add_column :commits, :detached, :boolean, null: false, default: false
  end
end
