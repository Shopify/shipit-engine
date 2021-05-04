# frozen_string_literal: true
require 'test_helper'

module Shipit
  class CheckRunTest < ActiveSupport::TestCase
    setup do
      @commit = shipit_commits(:first)
      @stack = @commit.stack
      @check_run = shipit_check_runs(:second_pending_travis)
    end

    test ".create_or_update_from_github! updates successfully" do
      checkrun_time = Time.now
      assert_difference -> { @commit.check_runs.count }, +1 do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(conclusion: nil, checkrun_time: '2021-04-29T18:05:12Z')
        )
      end

      assert_no_enqueued_jobs(only: RefreshCheckRunsJob) do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(conclusion: 'success', checkrun_time: checkrun_time + 1.minute)
        )
      end

      assert_equal 'success', @commit.check_runs.last.conclusion
    end

    test ".create_or_update_from_github! is idempotent" do
      checkrun_time = Time.now
      assert_difference -> { @commit.check_runs.count }, +1 do
        @commit.check_runs.create_or_update_from_github!(@stack.id, github_check_run(checkrun_time: checkrun_time))
      end

      assert_no_difference -> { @commit.check_runs.count } do
        assert_no_enqueued_jobs(only: RefreshCheckRunsJob) do
          @commit.check_runs.create_or_update_from_github!(@stack.id, github_check_run(checkrun_time: checkrun_time))
        end
      end
    end

    test ".create_or_update_from_github! enqueues refresh when new statuses have stale timestamps" do
      checkrun_time = Time.now
      assert_difference -> { @commit.check_runs.count }, +1 do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(conclusion: 'success', checkrun_time: checkrun_time)
        )
      end

      assert_no_difference -> { @commit.check_runs.count } do
        assert_enqueued_with(job: RefreshCheckRunsJob) do
          @commit.check_runs.create_or_update_from_github!(
            @stack.id,
            github_check_run(conclusion: nil, checkrun_time: checkrun_time - 1.minute)
          )
        end
      end
    end

    test ".create_or_update_from_github! enqueues refresh when new statues have no timestamps" do
      assert_no_difference -> { @commit.check_runs.count } do
        assert_enqueued_with(job: RefreshCheckRunsJob, args: [stack_id: @stack.id]) do
          @commit.check_runs.create_or_update_from_github!(
            @stack.id,
            github_check_run(conclusion: nil, checkrun_time: nil)
          )
        end
      end
    end

    {
      nil => 'pending',
      'success' => 'success',
      'failure' => 'failure',
      'neutral' => 'success',
      'cancelled' => 'failure',
      'timed_out' => 'error',
      'action_required' => 'pending',
    }.each do |conclusion, expected_status|
      test "#state is #{expected_status.inspect} when conclusion is #{conclusion.inspect}" do
        @check_run.update!(conclusion: conclusion)
        assert_equal expected_status, @check_run.state
      end
    end

    private

    def github_check_run(conclusion: 'success', checkrun_time: Time.now)
      OpenStruct.new(
        id: 424_242,
        conclusion: conclusion,
        output: OpenStruct.new(
          description: 'This is a description',
        ),
        name: 'Test Suite',
        html_url: 'http://example.com/run',
        details_url: 'http://example.com/details',
        completed_at: checkrun_time,
      )
    end
  end
end
