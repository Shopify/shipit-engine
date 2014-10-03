class CreateStatuses < ActiveRecord::Migration
  def change
    create_table :statuses do |t|
      t.string :state
      t.string :target_url
      t.text :description
      t.string :context
      t.references :commit, index: true

      t.timestamps
    end
  end
end
