# frozen_string_literal: true
namespace :cron do
  desc "Updates deployed revisions"
  task minutely: :environment do
    Shipit::Stack.refresh_deployed_revisions
    Shipit::Stack.schedule_continuous_delivery
    Shipit::GithubStatus.refresh_status
    Shipit::MergeRequest.schedule_merges
    Shipit::ReapDeadTasksJob.perform_later
    Shipit::ReviewStackProvisioningQueue.work
  end

  task hourly: %i(rollup refresh_users clear_stale_caches delete_old_deployment_directories)

  desc "Rolls-up output chunks for completed deploys older than an hour"
  task rollup: :environment do
    Shipit::Task.due_for_rollup.find_each(&:schedule_rollup_chunks)
  end

  task refresh_users: :environment do
    Shipit::User.refresh_shard(Time.now.hour % 24, 24)
  end

  task clear_stale_caches: :environment do
    Shipit::ReviewStack.clear_stale_caches
  end

  task delete_old_deployment_directories: :environment do
    Shipit::ReviewStack.delete_old_deployment_directories
  end
end
