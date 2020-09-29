class AddLabelsToPullRequests < ActiveRecord::Migration[6.0]
  def change
    add_column :pull_requests, :labels, :text
  end
end
