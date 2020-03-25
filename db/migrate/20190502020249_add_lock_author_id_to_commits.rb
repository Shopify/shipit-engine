# typed: true
class AddLockAuthorIdToCommits < ActiveRecord::Migration[5.2]
  def change
    add_column(:commits, :lock_author_id, :integer, limit: 4)
  end
end
