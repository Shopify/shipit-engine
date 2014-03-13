class ChangeCommitStateFromNilToEmpty < ActiveRecord::Migration
  def change
    Commit.where(state: nil).update_all(state: 'unknown')
  end
end
