class CreateStatusesForLegacyCommits < ActiveRecord::Migration
  def change
    Resque.enqueue(LegacyCommitStatusesMaintenanceJob, {})
  end
end
