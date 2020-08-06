class RenameCommitsPullRequestIdToMergeRequestId < ActiveRecord::Migration[6.0]
  def change
    rename_column :commits, :pull_request_id, :merge_request_id
  end
end
