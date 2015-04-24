class AllowNullCommitStats < ActiveRecord::Migration
  def change
    change_column_default :commits, :additions, nil
    change_column_default :commits, :deletions, nil
  end
end
