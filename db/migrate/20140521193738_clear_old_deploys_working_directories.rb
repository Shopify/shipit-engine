class ClearOldDeploysWorkingDirectories < ActiveRecord::Migration
  def change
    Deploy.completed.find_each(&:clear_working_directory)
  end
end
