class IndexPullRequestsOnMergeStatus < ActiveRecord::Migration[5.1]
  def change
    add_index :pull_requests, :merge_status
  end
end
