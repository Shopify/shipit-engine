class LegacyCommitStatusesMaintenanceJob < BackgroundJob

  def perform(_ = nil)
    Commit.preload(:statuses).find_each do |commit|
      if commit.statuses.empty? && commit.read_attribute(:state) != 'unknown'
        commit.statuses.create!(
          state: commit.read_attribute(:state),
          target_url: commit.read_attribute(:target_url),
          created_at: commit.updated_at,
        )
      end
    end
  end

end
