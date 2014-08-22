class AddRollbackRelatedColumnsToDeploys < ActiveRecord::Migration
  def change
    add_column :deploys, :type, :string, default: 'Deploy'
    add_column :deploys, :parent_id, :integer
  end
end
