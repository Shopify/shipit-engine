require 'test_helper'

module Shipit
  class CommitDeploymentTest < ActiveSupport::TestCase
    setup do
      @deployment = shipit_commit_deployments(:shipit_pending_fourth)
      @commit = @deployment.commit
      @task = @deployment.task
      @stack = @task.stack
      @author = @deployment.author
    end

    test "there can only be one record per deploy and commit pair" do
      assert_raises ActiveRecord::RecordNotUnique do
        CommitDeployment.create!(task: @deployment.task, commit: @deployment.commit)
      end
    end

    test "creation on GitHub" do
      pull_request_response = stub(head: stub(sha: '6dcb09b5b57875f334f61aebed695e2e4193db5e'))
      @author.github_api.expects(:pull_request).with('shopify/shipit-engine', 7).returns(pull_request_response)

      deployment_response = stub(id: 42, url: 'https://example.com')
      @author.github_api.expects(:create_deployment).with(
        'shopify/shipit-engine',
        pull_request_response.head.sha,
        auto_merge: false,
        required_contexts: [],
        description: "Via Shipit",
        environment: @stack.environment,
      ).returns(deployment_response)

      @deployment.create_on_github!
      assert_equal deployment_response.id, @deployment.github_id
      assert_equal deployment_response.url, @deployment.api_url
    end
  end
end
