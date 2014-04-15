class RemoveOutputFromDeploys < ActiveRecord::Migration
  def change
    remove_column :deploys, :output
  end
end
