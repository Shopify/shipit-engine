class ShipitPipelineChanges < ActiveRecord::Migration[6.0]
  def change
    change_column :predictive_builds, :status, :string, limit: 50
    change_column :predictive_builds, :branch, :string, limit: 100
    add_column :predictive_builds, :mode, :string, limit: 30,    default: "default",   null: false
    change_column :tasks, :type, :string, limit: 50

    create_table :predictive_branches do |t|
      t.references :predictive_build,               foreign_key: true, null: false, type: :bigint
      t.references :stack,               foreign_key: true, null: false, type: :int
      t.string      "status",               limit: 50,    default: "pending",   null: false
      t.string      "branch",               limit: 100,    null: false
      t.timestamps
    end


    change_table :tasks do |t|
      t.references :predictive_branch,       foreign_key: true, null: true, type: :bigint
    end

    remove_reference :predictive_merge_requests, :predictive_build, foreign_key: true, null: true, type: :bigint
    add_reference :predictive_merge_requests, :predictive_branch, foreign_key: true, null: true, type: :bigint
    add_reference :predictive_merge_requests, :head, foreign_key: {to_table: :commits}, null: false, type: :int
    add_reference :predictive_branches, :stack_commit, foreign_key: {to_table: :commits}, null: false, type: :int
    add_column :tasks, :predictive_task_type, :string, limit: 50

    change_column :tasks, :stack_id, foreign_key: true, null: true, type: :int, references: :stacks
    change_column :merge_requests, :mode, :string, limit: 30,    default: "default",   null: false
  end

end
