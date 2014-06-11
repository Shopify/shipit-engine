class CleanupTimeoutedDeploys < ActiveRecord::Migration
  def change
    Deploy.where(status: 'running').where('created_at < ?', 10.hours.ago).update_all(status: 'error')
  end
end
