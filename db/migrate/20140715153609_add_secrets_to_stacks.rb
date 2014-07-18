class AddSecretsToStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :secrets, :text, default: '{}', null: false
  end
end
