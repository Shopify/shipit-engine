class CreateShipitPipeline < ActiveRecord::Migration[6.0]
  def change
    #
    # TODO add FK to all tables below
    #
    create_table :pipelines do |t| # id: false
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

    create_table :predictive_builds do |t|
      t.references :pipeline,               foreign_key: true, null: false, type: :bigint
      t.string      "status",               limit: 10,    default: "pending",   null: false
      t.string      "branch",               limit: 10,    null: false

      t.timestamps
    end

    change_table :tasks do |t|
      t.references :predictive_build,       foreign_key: true, null: true, type: :bigint
    end

    create_table :predictive_merge_requests do |t|
      t.references :predictive_build,       foreign_key: true, null: true, type: :bigint
      t.references :merge_request,          foreign_key: true, null: false, type: :integer
      t.string      "status",               limit: 10,    default: "pending",   null: false

      t.timestamps
    end

    add_column :stacks, :pipeline_id, :integer, null: true
    add_index :stacks, :pipeline_id

    add_column :merge_requests, :mode, :string, limit: 10,    default: "default",   null: false
    add_index :merge_requests, [:stack_id, :mode, :merge_status, :merge_request_id, :merge_requested_at], name: :index_stack_mod_status
  end
end