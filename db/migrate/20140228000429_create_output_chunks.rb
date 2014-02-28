class CreateOutputChunks < ActiveRecord::Migration
  def change
    create_table :output_chunks do |t|
      t.references :deploy, index: true
      t.text :text

      t.timestamps
    end
  end
end
