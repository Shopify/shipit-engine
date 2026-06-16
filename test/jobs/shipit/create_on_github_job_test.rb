# frozen_string_literal: true

require 'test_helper'

module Shipit
  class CreateOnGithubJobTest < ActiveSupport::TestCase
    setup do
      @deployment = shipit_commit_deployments(:shipit_pending_fourth)
    end

    test "#perform retries on GitHub authentication errors" do
      CommitDeployment.any_instance.stubs(:create_on_github!).raises(Octokit::Unauthorized)

      assert_enqueued_with(job: CreateOnGithubJob) do
        CreateOnGithubJob.perform_now(@deployment)
      end
    end

    test "#perform gives up without re-raising after exhausting authentication retries" do
      CommitDeployment.any_instance.stubs(:create_on_github!).raises(Octokit::Unauthorized)
      Rails.logger.stubs(:warn)

      job = CreateOnGithubJob.new(@deployment)
      job.exception_executions = { "[Octokit::Unauthorized]" => 13 }

      assert_nothing_raised { job.perform_now }
    end
  end
end
