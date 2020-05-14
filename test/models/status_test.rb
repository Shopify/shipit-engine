# frozen_string_literal: true
require 'test_helper'

module Shipit
  class StatusTest < ActiveSupport::TestCase
    setup do
      @commit = shipit_commits(:first)
      @stack = @commit.stack
    end

    test ".replicate_from_github! is idempotent" do
      assert_difference '@commit.statuses.count', 1 do
        @commit.statuses.replicate_from_github!(@stack.id, github_status)
      end

      assert_no_difference '@commit.statuses.count' do
        @commit.statuses.replicate_from_github!(@stack.id, github_status)
      end
    end

    test "once created a commit broadcasts an update event" do
      expect_event(@stack)
      @commit.statuses.create!(stack_id: @stack.id, state: 'success')
    end

    test ".replicate_from_github! touches the related stack" do
      stack_last_updated_at = @stack.updated_at
      commit_last_updated_at = @commit.updated_at

      @commit.statuses.replicate_from_github!(@stack.id, github_status)

      assert_not_equal commit_last_updated_at, @commit.reload.updated_at
      assert_not_equal stack_last_updated_at, @stack.reload.updated_at
    end

    test ".simple_state returns failure when status is error" do
      assert_equal 'failure', Status.new(state: 'error').simple_state
    end

    test ".simple_state returns status when status is not error" do
      assert_equal 'success', Status.new(state: 'success').simple_state
      assert_equal 'failure', Status.new(state: 'failure').simple_state
    end

    private

    def github_status
      @github_status ||= OpenStruct.new(
        state: 'success',
        description: 'This is a description',
        context: 'default',
        target_url: 'http://example.com',
        created_at: 1.day.ago.to_time,
      )
    end

    def expect_event(stack)
      Pubsubstub.expects(:publish).at_least_once
      Pubsubstub.expects(:publish).with do |channel, _payload, options = {}|
        options[:name] == 'update' && channel == "stack.#{stack.id}"
      end
    end
  end
end
