class CreateReleaseStatuses < ActiveRecord::Migration[5.1]
  def change
    create_table :release_statuses do |t|
      t.references :stack, foreign_key: false, null: false, index: false
      t.references :commit, foreign_key: false, null: false, index: false
      t.references :user, foreign_key: false, null: true

      t.string :state, limit: 10, null: false
      t.string :description, limit: 1024, null: true
      t.string :target_url, limit: 1024, null: true

      t.bigint :github_id, null: true

      t.timestamps

      t.index %i(commit_id github_id)
      t.index %i(stack_id commit_id)
    end
  end
end

