class ChangeCommitMessageToText < ActiveRecord::Migration
  def up
    change_column :commits, :message, :text, :limit => nil
  end

  def down
    change_column :commits, :message, :string, :limit => 255
  end
end
