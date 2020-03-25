# typed: true
class CreateShipitRepositories < ActiveRecord::Migration[6.0]
  def change
    create_table :repositories do |t|
      t.string :owner, limit: 39, null: false
      t.string :name, limit: 100, null: false

      t.timestamps
    end

    add_index :repositories, ["owner", "name"], name: "repository_unicity", unique: true
  end
end
