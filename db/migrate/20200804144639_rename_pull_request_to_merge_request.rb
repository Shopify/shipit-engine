# frozen_string_literal: true

class RenamePullRequestToMergeRequest < ActiveRecord::Migration[6.0]
  def change
    rename_table :pull_requests, :merge_requests
  end
end
