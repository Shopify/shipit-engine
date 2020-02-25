require 'test_helper'

module Shipit
  class CommitDeploymentTest < ActiveSupport::TestCase
    setup do
      @deployment = shipit_commit_deployments(:shipit_pending_fourth)
      @task = @deployment.task
      @stack = @task.stack
      @author = @deployment.author
    end

    test "creation on GitHub" do
      deployment_response = stub(id: 42, url: 'https://example.com')
      @author.github_api.expects(:create_deployment).with(
        'shopify/shipit-engine',
        @deployment.sha,
        auto_merge: false,
        required_contexts: [],
        description: "Via Shipit",
        environment: @stack.environment,
        payload: {
          shipit: {
            task_id: 4,
            from_sha: 'f890fd8b5f2be05d1fedb763a3605ee461c39074',
            to_sha: '467578b362bf2b4df5903e1c7960929361c3435a',
          },
        }.to_json,
      ).returns(deployment_response)

      @deployment.create_on_github!
      assert_equal deployment_response.id, @deployment.github_id
      assert_equal deployment_response.url, @deployment.api_url
    end
  end
end
