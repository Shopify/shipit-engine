require 'test_helper'

module Shipit
  class ReapDeadTasksJobTest < ActiveSupport::TestCase
    setup do
      Task.where(status: Task::ACTIVE_STATUSES).update_all(status: 'success')

      not_recently = Shipit::Task.recently_created_at - 1.minute
      @deploy = shipit_deploys(:shipit)
      @deploy.status = 'success'
      @deploy.created_at = not_recently
      @deploy.save!

      @rollback = @deploy.build_rollback
      @rollback.status = 'running'
      @rollback.created_at = not_recently
      @rollback.save!

      @zombie_deploy = shipit_deploys(:shipit2)
      @zombie_deploy.status = 'running'
      @zombie_deploy.created_at = not_recently
      @zombie_deploy.save!
    end

    test 'reaps only zombie tasks' do
      refute_predicate @zombie_deploy, :error?

      Shipit::Deploy.any_instance.expects(:alive?).returns(false)
      Shipit::Rollback.any_instance.expects(:alive?).returns(true)
      ReapDeadTasksJob.perform_now

      @zombie_deploy.reload
      assert_predicate @zombie_deploy, :error?

      @deploy.reload
      assert_predicate @deploy, :finished?

      @rollback.reload
      assert_predicate @rollback, :running?
    end

    test "does reap recently created tasks" do
      Task.where(status: Task::ACTIVE_STATUSES).update_all(status: 'success')
      recently = Time.current
      @deploy = shipit_deploys(:shipit)
      @deploy.created_at = recently
      @deploy.status = 'running'
      @deploy.save!
      Shipit::Deploy.any_instance.expects(:alive?).never

      ReapDeadTasksJob.perform_now

      @deploy.reload
      assert_predicate @deploy, :running?
    end

    test 'reaps zombie aborting tasks' do
      deploy = shipit_deploys(:shipit2)
      deploy.status = 'aborting'
      deploy.save!

      ReapDeadTasksJob.perform_now

      assert_predicate deploy.reload, :error?
    end
  end
end
