# frozen_string_literal: true
require 'test_helper'

module Shipit
  class GithubSyncJobTest < ActiveSupport::TestCase
    setup do
      @job = GithubSyncJob.new
      @stack = shipit_stacks(:shipit)
      @github_commits = stub
    end

    test "#perform fetch commits from the API" do
      Stack.any_instance.expects(:github_commits).returns(@github_commits)
      @job.expects(:fetch_missing_commits).yields.returns([[], nil])
      @job.perform(stack_id: @stack.id)
    end

    test "#perform finally enqueue a CacheDeploySpecJob" do
      Stack.any_instance.stubs(:github_commits).returns(@github_commits)
      @job.stubs(:fetch_missing_commits).yields.returns([[], nil])

      assert_enqueued_with(job: CacheDeploySpecJob, args: [@stack]) do
        @job.perform(stack_id: @stack.id)
      end
    end

    test "#perform mark all childs of the common parent as detached" do
      Stack.any_instance.expects(:github_commits).returns(@github_commits)
      @job.expects(:fetch_missing_commits).yields.returns([[], shipit_commits(:third)])

      refute shipit_commits(:fourth).reload.detached?
      refute shipit_commits(:fifth).reload.detached?

      @job.perform(stack_id: @stack.id)

      assert shipit_commits(:fourth).reload.detached?
      assert shipit_commits(:fifth).reload.detached?
    end

    test "#perform locks all commits leading to a revert" do
      @stack.deploys_and_rollbacks.destroy_all

      initial_queue = [
        ["whoami", false],
        ["fix all the things", false],
        ["yoloshipit!", false],
        ["fix it!", false],
        ["sheep it!", false],
        ["lets go", false],
      ]
      assert_equal initial_queue, @stack.undeployed_commits.map { |c| [c.title, c.locked?] }

      author = stub(
        id: 1234,
        login: 'bob',
        name: 'Bob the Builder',
        email: 'bob@bob.com',
        date: '2011-04-14T16:00:49Z',
      )
      @job.expects(:fetch_missing_commits).returns([
        [
          stub(
            sha: '36514755579bfb5bc313f403b216f4347a027990',
            author: author,
            committer: author,
            stats: nil,
            commit: stub(
              sha: '36514755579bfb5bc313f403b216f4347a027990',
              message: 'Revert "fix it!"',
              author: author,
              committer: author,
            ),
          ),
        ],
        shipit_commits(:fifth),
      ])
      @job.perform(stack_id: @stack.id)

      final_queue = [
        ['Revert "fix it!"', false],
        ["fix all the things", true],
        ["yoloshipit!", true],
        ["fix it!", true],
        ["sheep it!", false],
        ["lets go", false],
      ]
      assert_equal final_queue, @stack.reload.undeployed_commits.map { |c| [c.title, c.locked?] }
    end

    test "#fetch_missing_commits returns the commits in the reverse order if it doesn't know the parent" do
      last = stub(sha: 123)
      first = stub(sha: 345)
      Shipit::FirstParentCommitsIterator.any_instance.stubs(:each).multiple_yields(last, first)
      @job.stubs(lookup_commit: nil)

      commits, parent = @job.fetch_missing_commits { stub }
      assert_nil parent
      assert_equal [first, last], commits
    end

    test "#fetch_missing_commits returns the commits in the reverse order if it knows the parent" do
      last = stub(sha: 123)
      first = stub(sha: 345)
      Shipit::FirstParentCommitsIterator.any_instance.stubs(:each).multiple_yields(last, first)
      @job.stubs(:lookup_commit).with(123).returns(nil)
      @job.stubs(:lookup_commit).with(345).returns(first)

      commits, parent = @job.fetch_missing_commits { stub }
      assert_equal first, parent
      assert_equal [last], commits
    end

    test "if GitHub returns a 404, the stacks is marked as inaccessible" do
      @job.expects(:fetch_missing_commits).raises(Octokit::NotFound)
      @job.perform(stack_id: @stack.id)

      assert_equal true, @stack.reload.inaccessible_since?
    end
  end
end
