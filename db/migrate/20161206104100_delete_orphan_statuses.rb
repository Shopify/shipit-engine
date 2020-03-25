# typed: false
class DeleteOrphanStatuses < ActiveRecord::Migration[5.0]
  def up
    ids = Shipit::Status.left_joins(:commit).where(commits: {id: nil}).pluck(:id)
    say "Found #{ids.size} orphan statuses"
    Shipit::Status.where(id: ids).delete_all
  end

  def down
  end
end
