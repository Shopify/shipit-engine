class DenormalizeDeployStats < ActiveRecord::Migration
  def change
    add_column :deploys, :additions, :integer, default: 0
    add_column :deploys, :deletions, :integer, default: 0
  end
end
