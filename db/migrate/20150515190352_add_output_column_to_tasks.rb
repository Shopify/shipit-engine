# typed: false
class AddOutputColumnToTasks < ActiveRecord::Migration[4.2]
  def change
    add_column :tasks, :gzip_output, :binary, limit: 16777215
  end
end
