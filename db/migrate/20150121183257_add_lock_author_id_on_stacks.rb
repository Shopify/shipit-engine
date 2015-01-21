class AddLockAuthorIdOnStacks < ActiveRecord::Migration
  def change
    add_column :stacks, :lock_author_id, :integer
  end
end
