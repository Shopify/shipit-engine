class DropChecklistOnStacks < ActiveRecord::Migration
  def change
    remove_column :stacks, :checklist
  end
end
