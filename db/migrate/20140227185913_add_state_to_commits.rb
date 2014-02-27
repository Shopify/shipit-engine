class AddStateToCommits < ActiveRecord::Migration
  def change
    add_column :commits, :state, :string
  end
end
