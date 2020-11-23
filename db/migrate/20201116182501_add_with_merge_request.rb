class AddWithMergeRequest < ActiveRecord::Migration[6.0]
  def change
    add_column :merge_requests, :merge_request_id, :integer, null: true
    add_index :merge_requests, :merge_request_id
  end
end
