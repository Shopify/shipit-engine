class CreateTeams < ActiveRecord::Migration
  def change
    create_table :teams do |t|
      t.integer :github_id
      t.string :api_url
      t.string :slug
      t.string :name
      t.string :organization

      t.timestamps null: false

      t.index %i(organization slug), unique: true
    end
  end
end
