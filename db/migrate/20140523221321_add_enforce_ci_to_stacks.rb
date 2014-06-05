class AddEnforceCiToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :enforce_ci, :boolean, null: false, default: true
  end
end
