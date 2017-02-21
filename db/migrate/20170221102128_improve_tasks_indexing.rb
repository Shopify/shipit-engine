class ImproveTasksIndexing < ActiveRecord::Migration[5.0]
  def change
    # index_active_tasks should superseed this, but for some reason
    # MySQL tend to chose the wrong index. This one while wasting a bit of memory
    # makes it do a better choice.
    add_index :tasks, %i(stack_id allow_concurrency)
  end
end
