class AddChecklistToStack < ActiveRecord::Migration
  def change
    add_column :stacks, :checklist, :text, default: nil, null: true
  end
end
