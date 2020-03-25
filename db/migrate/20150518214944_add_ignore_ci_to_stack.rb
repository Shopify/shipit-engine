# typed: false
class AddIgnoreCiToStack < ActiveRecord::Migration[4.2]
  def change
    add_column :stacks, :ignore_ci, :boolean
  end
end
