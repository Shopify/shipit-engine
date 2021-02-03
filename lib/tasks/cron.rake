# frozen_string_literal: true
namespace :cron do
  desc "Updates deployed revisions"
  task minutely: :environment do

    # The following job is not optimal and its overloading both Jenkins and Sidekiq
    Rails.cache.fetch('shipit::minutely::refresh_deployed_revisions', expires_in: 5.minutes) do
      Shipit::Stack.refresh_deployed_revisions
    end

    Shipit::Stack.schedule_continuous_delivery
    Shipit::Pipeline.schedule_predictive_build
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
