class RenameDeploysInTasks < ActiveRecord::Migration
  def up
    connection.execute(%(
      UPDATE deploys
      SET type = 'Deploy'
      WHERE type IS NULL
      OR type = ''
    ))
    rename_table :deploys, :tasks
    rename_column :stacks, :deploys_count, :tasks_count
    rename_column :output_chunks, :deploy_id, :task_id
  end

  def down
    rename_table :tasks, :deploys
    rename_column :stacks, :tasks_count, :deploys_count
    rename_column :output_chunks, :task_id, :deploy_id
  end
end
