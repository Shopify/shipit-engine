class AddReviewRequestColumnToPullRequestsTable < ActiveRecord::Migration[6.0]
  def up
    change_table(:pull_requests) do |t|
      t.boolean :review_request, null: true, default: false
    end
  end

  def down
    change_table(:pull_requests) do |t|
      t.remove :review_request
    end
  end
end
