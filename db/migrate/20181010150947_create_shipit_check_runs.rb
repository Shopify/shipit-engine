# typed: true
class CreateShipitCheckRuns < ActiveRecord::Migration[5.1]
  def change
    create_table :check_runs do |t|
      t.references :stack, foreign_key: false, null: false
      t.references :commit, foreign_key: false, null: false
      t.bigint :github_id, null: false
      t.string :name, null: false
      t.string :conclusion, limit: 20, null: true
      t.string :title, limit: 1024
      t.string :details_url
      t.string :html_url
      t.timestamps

      t.index %i(github_id commit_id), unique: true
    end
  end
end
