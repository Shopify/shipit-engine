class ClearOldDeploysWorkingDirectories < ActiveRecord::Migration
  def change
    Deploy.completed.find_each do |deploy|
      if deploy.stack
        deploy.clear_working_directory
      else
        deploy.destroy
      end
    end
  end
end
