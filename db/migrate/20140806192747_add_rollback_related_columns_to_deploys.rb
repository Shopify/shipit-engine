class AddRollbackRelatedColumnsToDeploys < ActiveRecord::Migration
  def change
    add_column :deploys, :rollback, :boolean, default: false
    add_column :deploys, :parent_id, :integer

    add_index :deploys, :rollback
  end
end
