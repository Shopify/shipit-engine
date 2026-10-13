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

    test "#perform retries failed deployment statuses without recreating published records" do
      status = shipit_commit_deployment_statuses(:shipit2_deploy_third_in_progress)
      deployment = status.commit_deployment
      shipit_commit_deployment_statuses(:shipit2_deploy_third_failure).update!(github_id: 43)
      response = stub(id: 44, url: "#{deployment.api_url}/statuses/44")
      client_class = deployment.stack.github_api.class
      client_class.any_instance.expects(:create_deployment).never
      client_class.any_instance.expects(:create_deployment_status)
                  .with(deployment.api_url, 'in_progress', anything).twice
                  .raises(Octokit::InternalServerError).then.returns(response)

      assert_enqueued_with(job: CreateOnGithubJob) { CreateOnGithubJob.perform_now(deployment) }
      assert_nil status.reload.github_id

      retry_job = enqueued_jobs.last
      clear_enqueued_jobs
      assert_no_enqueued_jobs { ActiveJob::Base.execute(retry_job) }

      assert_equal response.id, status.reload.github_id
      assert_equal response.url, status.api_url
    end

    test "#perform re-raises after exhausting GitHub server error retries" do
      CommitDeployment.any_instance.stubs(:create_on_github!).raises(Octokit::InternalServerError)
      job = CreateOnGithubJob.new(@deployment)
      job.exception_executions = { "[Octokit::ServerError]" => 9 }

      assert_no_enqueued_jobs do
        assert_raises(Octokit::InternalServerError) { job.perform_now }
      end
    end
  end
end
