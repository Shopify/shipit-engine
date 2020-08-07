class RenamePullRequestAssignmentPullRequestToMergeRequest < ActiveRecord::Migration[6.0]
  def change
    rename_column :pull_request_assignments, :pull_request_id, :merge_request_id
  end
end
