class RemoveStacksBranchDefault < ActiveRecord::Migration[6.1]
  def change
    change_column_default(:stacks, :branch, from: 'master', to: nil)
  end
end
