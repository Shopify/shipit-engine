# frozen_string_literal: true
require 'test_helper'

module Shipit
  class BackgroundJobTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @last_commit = @stack.commits.last
      @job = CacheDeploySpecJob.new
      @user = shipit_users(:walrus)
    end

    test "#perform retries on Octokit secondary rate limit exceptions" do
      freeze_time do
        Octokit::Forbidden.any_instance.expects(:response_headers)
          .returns({ "Retry-After" => 45 })

        Shipit.github.api.expects(:user).with(@user.github_id).raises(Octokit::TooManyRequests)

        assert_enqueued_with(job: BackgroundStubJob, at: Time.now + 45.seconds) do
          BackgroundStubJob.perform_now(@user)
        end
      end
    end

    class BackgroundStubJob < BackgroundJob
      queue_as :default

      def perform(user)
        Shipit.github.api.user(user.github_id)
      end
    end
  end
end
