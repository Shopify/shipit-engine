class AddRolledUpToDeploys < ActiveRecord::Migration
  def up
    add_column :deploys, :rolled_up, :boolean, default: false, null: false
    add_index :deploys, [:rolled_up, :created_at, :status]

    Deploy.completed.find_each do |deploy|
      next if deploy.chunks.count > 1
      deploy.update_attribute(:rolled_up, true)
    end
  end

  def down
    remove_index :deploys, [:rolled_up, :created_at, :status]
    remove_column :deploys, :rolled_up
  end
end
