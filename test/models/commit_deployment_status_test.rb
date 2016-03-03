require 'test_helper'

module Shipit
  class CommitDeploymentStatusTest < ActiveSupport::TestCase
    setup do
      @status = shipit_commit_deployment_statuses(:shipit2_deploy_third_pending)
      @deployment = @status.commit_deployment
      @task = @deployment.task
      @commit = @deployment.commit
    end

    test 'creation on GitHub' do
      response = stub(id: 44, url: 'https://example.com')
      Shipit.github_api.expects(:create_deployment_status).with(
        @deployment.api_url,
        'pending',
        target_url: "http://shipit.com/shopify/shipit-engine/production/deploys/#{@task.id}",
        description: "walrus triggered the deploy of shopify/shipit-engine/production to #{@commit.sha}",
      ).returns(response)

      @status.create_on_github!
      assert_equal response.id, @status.github_id
      assert_equal response.url, @status.api_url
    end
  end
end
