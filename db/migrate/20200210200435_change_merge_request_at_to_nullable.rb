class ChangeMergeRequestAtToNullable < ActiveRecord::Migration[6.0]
  def change
    change_column_null(:pull_requests, :merge_requested_at, true)
  end

  def down
    change_column_null(:pull_requests, :merge_requested_at, false)
  end
end
