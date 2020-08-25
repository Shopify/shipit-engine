# frozen_string_literal: true
class RemoveReviewRequestFlagFromMergeRequests < ActiveRecord::Migration[6.0]
  def up
    remove_column :merge_requests, :review_request
  end

  def down
    change_table(:pull_requests) do |t|
      t.boolean :review_request, null: true, default: false
    end
  end
end
