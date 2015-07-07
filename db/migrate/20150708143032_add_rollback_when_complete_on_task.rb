class AddRollbackWhenCompleteOnTask < ActiveRecord::Migration
  def change
    add_column :tasks, :rollback_once_aborted, :boolean, default: false, null: false
  end
end
