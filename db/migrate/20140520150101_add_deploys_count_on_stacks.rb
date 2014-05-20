class AddDeploysCountOnStacks < ActiveRecord::Migration
  def up
    add_column :stacks, :deploys_count, :integer, default: 0, null: false
    Stack.reset_column_information
    Stack.find_each do |stack|
      Stack.reset_counters(stack.id, :deploys)
    end
  end

  def down
    remove_column :stacks, :deploys_count
  end
end
