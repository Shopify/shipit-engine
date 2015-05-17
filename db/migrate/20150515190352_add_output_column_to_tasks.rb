class AddOutputColumnToTasks < ActiveRecord::Migration
  def change
    add_column :tasks, :gzip_output, :binary, limit: 16777215
  end
end
