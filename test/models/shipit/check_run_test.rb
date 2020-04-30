# frozen_string_literal: true
require 'test_helper'

module Shipit
  class CheckRunTest < ActiveSupport::TestCase
    setup do
      @commit = shipit_commits(:first)
      @stack = @commit.stack
      @check_run = shipit_check_runs(:second_pending_travis)
    end

    test ".create_or_update_from_github! is idempotent" do
      assert_difference -> { @commit.check_runs.count }, +1 do
        @commit.check_runs.create_or_update_from_github!(@stack.id, github_check_run)
      end

      assert_no_difference -> { @commit.check_runs.count } do
        @commit.check_runs.create_or_update_from_github!(@stack.id, github_check_run)
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

    def github_check_run
      @github_check_run ||= OpenStruct.new(
        id: 424_242,
        conclusion: 'success',
        output: OpenStruct.new(
          description: 'This is a description',
        ),
        name: 'Test Suite',
        html_url: 'http://example.com/run',
        details_url: 'http://example.com/details',
      )
    end
  end
end
