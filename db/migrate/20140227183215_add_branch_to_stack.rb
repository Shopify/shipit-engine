class AddBranchToStack < ActiveRecord::Migration
  def change
    add_column :stacks, :branch, :string, null: false, default: :master
  end
end
