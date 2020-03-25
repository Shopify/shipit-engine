# typed: false
class AddMergedAtOnPullRequests < ActiveRecord::Migration[5.0]
  def up
    add_column :pull_requests, :merged_at, :datetime
  end

  def down
    remove_column :pull_requests, :merged_at
  end
end
