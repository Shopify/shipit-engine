require 'test_helper'

module Shipit
  class CreateDeploymentsForTaskJobTest < ActiveSupport::TestCase
    setup do
      @task = shipit_tasks(:shipit_pending)
      @task.commit_deployments.delete_all
    end

    test "creates one CommitDeployment and status per commit, and one more for the batch head" do
      pull_request_response = stub(head: stub(sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e'))
      Shipit.github.api.expects(:pull_request).with('shopify/shipit-engine', 7).returns(pull_request_response)

      expected_delta = @task.commits.select(&:pull_request?).size + 1
      assert_difference -> { CommitDeployment.count }, expected_delta do
        assert_difference -> { CommitDeploymentStatus.count }, expected_delta do
          CreateDeploymentsForTaskJob.perform_now(@task)
        end
      end

      refute_nil CommitDeployment.find_by(sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e')
      refute_nil CommitDeployment.find_by(sha: @task.until_commit.sha)
    end
  end
end
