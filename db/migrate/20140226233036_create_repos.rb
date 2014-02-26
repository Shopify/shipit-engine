class CreateRepos < ActiveRecord::Migration
  def change
    create_table :repos do |t|
      t.string :name, null: false
      t.string :owner, null: false

      t.timestamps
    end
  end
end
