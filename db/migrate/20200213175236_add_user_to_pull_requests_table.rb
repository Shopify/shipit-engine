class AddUserToPullRequestsTable < ActiveRecord::Migration[6.0]
  def change
    change_table(:pull_requests) do |t|
      t.references :user
    end
  end

  def down
    change_table(:pull_requests) do |t|
      t.remove_references :user
    end
  end
end
