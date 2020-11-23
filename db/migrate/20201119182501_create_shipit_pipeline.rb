class CreateShipitPipeline < ActiveRecord::Migration[6.0]
  def change
    create_table :pipelines do |t|
      t.string   "name",                     limit: 100,                          null: false
      t.string   "environment",              limit: 50,    default: "production", null: false
      t.string   "lock_reason",              limit: 255
      t.integer  "lock_author_id",           limit: 4
      t.datetime "locked_since"
      t.datetime "archived_since"

      t.datetime "last_cd_at"
      t.datetime "last_ci_at"

      t.timestamps

      t.index [:archived_since]
      t.index [:environment]
    end

    create_table :release do |t|
      t.integer     "pipeline_id",          limit: 4
      # pending, aborted, completed, partial, failure
      t.string      "status",               limit: 10,    default: "pending",   null: false
      t.datetime    "started_at"
      t.datetime    "ended_at"

      t.timestamps

      t.index [:pipeline_id]
    end

    create_table :release_merge_requests do |t|
      t.integer     "release_id",          limit: 4
      t.integer     "merge_request_id",    limit: 4

      # pending, aborted, completed, failure
      t.string      "status",               limit: 10,    default: "pending",   null: false

      t.timestamps

      t.index [:release_id]
      t.index [:merge_request_id]
    end


    add_column :stacks, :pipeline_id, :integer, null: true
    add_index :stacks, [:pipeline_id, :merge_status]
  end
end