class RemoveTasksTypeDefault < ActiveRecord::Migration
  def change
    change_column_default :tasks, :type, nil
    change_column_null :tasks, :type, true
  end
end
