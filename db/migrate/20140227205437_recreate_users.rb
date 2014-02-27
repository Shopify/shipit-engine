class RecreateUsers < ActiveRecord::Migration
  def change
    drop_table :users

    create_table :users do |t|
      t.integer :github_id

      t.string :name,  null: false
      t.string :email, null: false
      t.string :login
      t.string :api_url

      t.timestamps
    end
  end
end
