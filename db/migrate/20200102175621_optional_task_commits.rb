# typed: true
class OptionalTaskCommits < ActiveRecord::Migration[6.0]
  def change
    change_column_null :tasks, :since_commit_id, true
    change_column_null :tasks, :until_commit_id, true
  end
end
