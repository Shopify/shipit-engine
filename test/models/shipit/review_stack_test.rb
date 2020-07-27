# frozen_string_literal: true

require 'test_helper'

module Shipit
  class ReviewStackTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:review_stack)
    end

    test ".review_request is nil by default" do
      assert_nil @stack.review_request
    end

    test ".review_request returns nil when all pull requests are merge requests" do
      assert_nil @stack.review_request
    end

    test ".review_request returns latest non merge request" do
      @pull_request = PullRequest.create!(stack: @stack, number: "1", review_request: true)

      assert @stack.review_request, @pull_request
    end
  end
end
