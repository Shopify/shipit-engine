class MergeRequestsNewIndex < ActiveRecord::Migration[6.0]

  def change
    add_index :merge_requests, [:stack_id, :merge_status, :head_id], name: :index_status_head
  end

end

