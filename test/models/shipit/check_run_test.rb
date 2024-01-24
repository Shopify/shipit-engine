# frozen_string_literal: true

require 'test_helper'

module Shipit
  class CheckRunTest < ActiveSupport::TestCase
    Struct.new('GithubCheckRun', :id, :conclusion, :output, :name, :html_url, :details_url, :completed_at, :started_at)
    Struct::GithubCheckRun.superclass
    Struct.new('Output', :description, :title)
    Struct::Output.superclass

    setup do
      @commit = shipit_commits(:first)
      @stack = @commit.stack
      @check_run = shipit_check_runs(:second_pending_travis)
    end

    test ".create_or_update_from_github! updates successfully" do
      completed_at = Time.now
      assert_difference -> { @commit.check_runs.count }, +1 do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(conclusion: nil, completed_at: '2021-04-29T18:05:12Z'),
        )
      end

      assert_no_enqueued_jobs(only: RefreshCheckRunsJob) do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(conclusion: 'success', completed_at: completed_at + 1.minute),
        )
      end

      assert_equal 'success', @commit.check_runs.last.conclusion
    end

    test ".create_or_update_from_github! updates successfully using latest timestamp" do
      completed_at = Time.now
      assert_difference -> { @commit.check_runs.count }, +1 do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(conclusion: 'success', completed_at:),
        )
      end

      assert_enqueued_with(job: RefreshCheckRunsJob) do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(conclusion: nil, completed_at:),
        )
      end

      # RefreshCheckRunsJob would enqueue if the timestamp was older/equivalent
      assert_no_enqueued_jobs(only: RefreshCheckRunsJob) do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(
            conclusion: 'action_required',
            completed_at:,
            started_at: completed_at + 1.minute,
          ),
        )
      end

      assert_equal 'action_required', @commit.check_runs.last.conclusion
    end

    test ".create_or_update_from_github! is idempotent" do
      completed_at = Time.now
      assert_difference -> { @commit.check_runs.count }, +1 do
        @commit.check_runs.create_or_update_from_github!(@stack.id, github_check_run(completed_at:))
      end

      assert_no_difference -> { @commit.check_runs.count } do
        assert_no_enqueued_jobs(only: RefreshCheckRunsJob) do
          @commit.check_runs.create_or_update_from_github!(@stack.id, github_check_run(completed_at:))
        end
      end
    end

    test ".create_or_update_from_github! enqueues refresh and updates record when new statuses have stale timestamps" do
      completed_at = Time.now
      assert_difference -> { @commit.check_runs.count }, +1 do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(conclusion: 'success', completed_at:),
        )
      end

      assert_equal 'success', @commit.check_runs.last.conclusion

      updated_conclusion = 'action_required'
      updated_check_run = github_check_run(conclusion: updated_conclusion, completed_at: completed_at - 1.minute)

      assert_no_difference -> { @commit.check_runs.count } do
        assert_enqueued_with(job: RefreshCheckRunsJob) do
          @commit.check_runs.create_or_update_from_github!(@stack.id, updated_check_run)
        end
      end

      assert_equal updated_conclusion, @commit.check_runs.last.conclusion

      # If the refresh returns the same data, then the record should end up the same, but no refresh should be necessary
      assert_no_difference -> { @commit.check_runs.count } do
        assert_no_enqueued_jobs(only: RefreshCheckRunsJob) do
          @commit.check_runs.create_or_update_from_github!(@stack.id, updated_check_run)
        end
      end

      assert_equal updated_conclusion, @commit.check_runs.last.conclusion
    end

    test ".create_or_update_from_github! does not enqueues refresh when old statuses has no timestamp" do
      completed_at = Time.now
      assert_difference -> { @commit.check_runs.count }, +1 do
        @commit.check_runs.create_or_update_from_github!(
          @stack.id,
          github_check_run(conclusion: 'success', completed_at:),
        )
      end

      @commit.check_runs.last.update!(github_updated_at: nil)

      assert_no_difference -> { @commit.check_runs.count } do
        assert_no_enqueued_jobs(only: RefreshCheckRunsJob) do
          @commit.check_runs.create_or_update_from_github!(
            @stack.id,
            github_check_run(conclusion: nil, completed_at: completed_at - 1.minute),
          )
        end
      end
    end

    test ".create_or_update_from_github! enqueues refresh when new statuses have no timestamps" do
      assert_no_difference -> { @commit.check_runs.count } do
        assert_enqueued_with(job: RefreshCheckRunsJob, args: [stack_id: @stack.id]) do
          @commit.check_runs.create_or_update_from_github!(
            @stack.id,
            github_check_run(conclusion: nil, completed_at: nil, started_at: nil),
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
        @check_run.update!(conclusion:)
        assert_equal expected_status, @check_run.state
      end
    end

    private

    def github_check_run(conclusion: 'success', completed_at: Time.now, started_at: Time.now - 1.minute)
      Struct::GithubCheckRun.new(
        424_242,
        conclusion,
        Struct::Output.new(
          description: 'This is a description',
        ),
        'Test Suite',
        'http://example.com/run',
        'http://example.com/details',
        completed_at,
        started_at,
      )
    end
  end
end
