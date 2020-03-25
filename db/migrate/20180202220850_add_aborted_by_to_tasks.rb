# typed: true
class AddAbortedByToTasks < ActiveRecord::Migration[5.1]
  def change
    add_column :tasks, :aborted_by_id, :integer
  end
end
