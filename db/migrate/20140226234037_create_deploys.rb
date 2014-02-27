class CreateDeploys < ActiveRecord::Migration
  def change
    create_table :deploys do |t|
      t.references :stack, index: true, null: false
      t.references :since_commit, index: true, null: false
      t.references :until_commit, index: true, null: false
      t.string :status

      t.text :output

      t.timestamps
    end
  end
end
