class AddLabelsToPullRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :labels do |t|
      t.string :name

      t.index [:name], unique: true
    end

    create_table :pull_request_labels do |t|
      t.references :pull_request, null: false
      t.references :label, null: false

      t.index [:pull_request_id, :label_id], unique: true
    end
  end
end
