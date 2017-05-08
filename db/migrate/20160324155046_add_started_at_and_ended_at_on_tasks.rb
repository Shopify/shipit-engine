class AddStartedAtAndEndedAtOnTasks < ActiveRecord::Migration[4.2]
  def up
    add_column :tasks, :started_at, :datetime, null: true
    add_column :tasks, :ended_at, :datetime, null: true

    say "Migrating #{Shipit::Task.count} tasks:"
    Shipit::Task.find_each.with_index do |task, index|
      unless task.started_at
        task.update_columns(
          started_at: task.created_at,
          ended_at: task.updated_at, # good enough approximation but not perfect
        )
        puts if index % 100 == 0
        print '.'
      end
    end
    puts
    say "Done"
  end

  def down
    remove_column :tasks, :started_at
    remove_column :tasks, :ended_at
  end
end
