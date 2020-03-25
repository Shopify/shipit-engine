# typed: true
class AddBranchToPullRequests < ActiveRecord::Migration[5.0]
  def change
    add_column :pull_requests, :branch, :string, null: true
  end
end
