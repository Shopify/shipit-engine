class ChangeOutputChunkTextType < ActiveRecord::Migration
  def change
    change_column :output_chunks, :text, :text, limit: 1.megabyte
  end
end
