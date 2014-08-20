class ChangeOutputChunkTextType < ActiveRecord::Migration
  def up
    change_column :output_chunks, :text, :text, limit: 1.megabyte
  end

  def down
    change_column :output_chunks, :text, :text, limit: 1.megabyte
  end
end
