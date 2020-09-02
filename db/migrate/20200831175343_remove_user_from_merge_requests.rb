# frozen_string_literal: true
class RemoveUserFromMergeRequests < ActiveRecord::Migration[6.0]
  def change
    remove_reference :merge_requests, :user
  end
end
