class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users, id: false do |t|
      t.integer :id, :options => 'PRIMARY KEY'
      t.string :email
      t.string :login
      t.text :payload

      t.timestamps
    end
  end
end
