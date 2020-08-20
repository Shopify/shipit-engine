# frozen_string_literal: true

require "test_helper"

module Shipit
  class ReviewStackTest < ActiveSupport::TestCase
    setup do
      @review_stack = shipit_stacks(:review_stack)
    end

    test "clearing stale caches" do
      # Asserting that :archived_25hours_ago, :archived_30minutes_ago and :shipit are not queued.
      assert_enqueued_jobs 1 do
        assert_enqueued_with(job: Shipit::ClearGitCacheJob, args: [shipit_stacks(:archived_6hours_ago)]) do
          ReviewStack.clear_stale_caches
        end
      end
    end

    test "creating a review stack emits a hook" do
      new_review_stack = @review_stack.dup
      new_review_stack.environment = "new-review-stack-environment"

      expect_hook(:review_stack, new_review_stack, action: :added, review_stack: new_review_stack) do
        new_review_stack.save!
      end
    end

    test "updating a review stack emit a hook" do
      expect_hook(:review_stack, @review_stack, action: :updated, review_stack: @review_stack) do
        @review_stack.update(environment: 'foo')
      end
    end

    test "updating a review stack doesn't emit a hook if only `updated_at` is changed" do
      # force a save to make sure `cached_deploy_spec` serialization is consistent with how Active Record would
      # serialize it.
      @review_stack.update(updated_at: 2.days.ago)

      expect_no_hook(:review_stack) do
        @review_stack.update(updated_at: Time.zone.now)
      end
    end

    test "deleteing a review stack emits a hook" do
      expect_hook(:review_stack, @review_stack, action: :removed, review_stack: @review_stack) do
        @review_stack.destroy!
      end
    end

    test "#env includes the stack's pull request labels" do
      stack = shipit_stacks(:review_stack)
      stack.pull_request.labels = [
        Shipit::Label.find_or_create_by(name: "wip"),
        Shipit::Label.find_or_create_by(name: "bug"),
      ]

      assert_equal stack.env["WIP"], "true"
      assert_equal stack.env["BUG"], "true"
    end
  end
end
