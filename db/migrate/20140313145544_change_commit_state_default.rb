class ChangeCommitStateDefault < ActiveRecord::Migration
  def up
    change_column :commits, :state, :string, default: "unknown", null: false
  end

  def down
    change_column :commits, :state, :string, default: nil, null: true
  end
end
