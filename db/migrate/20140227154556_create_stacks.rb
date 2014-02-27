class CreateStacks < ActiveRecord::Migration
  def change
    create_table :stacks do |t|
      t.string :repo_name, null: false
      t.string :repo_owner, null: false
      t.string :environment, null: false, default: :production

      t.timestamps
    end
  end
end
