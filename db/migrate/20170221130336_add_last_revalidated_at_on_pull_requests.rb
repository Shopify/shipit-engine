class AddLastRevalidatedAtOnPullRequests < ActiveRecord::Migration[5.0]
  def up
    add_column :pull_requests, :revalidated_at, :datetime
    Shipit::PullRequest.update_all('revalidated_at = merge_requested_at')
  end

  def down
    remove_column :pull_requests, :revalidated_at
  end
end
