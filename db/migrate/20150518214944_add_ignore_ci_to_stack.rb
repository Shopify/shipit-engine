class AddIgnoreCiToStack < ActiveRecord::Migration
  def change
    add_column :stacks, :ignore_ci, :boolean
  end
end
