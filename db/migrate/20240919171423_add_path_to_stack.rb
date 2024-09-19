class AddPathToStack < ActiveRecord::Migration[7.2]
  def change
    add_column :stacks, :path, :string
  end
end
