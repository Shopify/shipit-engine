# frozen_string_literal: true
require 'test_helper'

module Shipit
  class CommitDeploymentStatusTest < ActiveSupport::TestCase
    setup do
      @status = shipit_commit_deployment_statuses(:shipit2_deploy_third_in_progress)
      @deployment = @status.commit_deployment
      @task = @deployment.task
      @author = @deployment.author
    end

    test 'creation on GitHub' do
      response = stub(id: 44, url: 'https://example.com')
      @author.github_api.class.any_instance.expects(:create_deployment_status).with(
        @deployment.api_url,
        'in_progress',
        target_url: "http://shipit.com/shopify/shipit-engine/production/deploys/#{@task.id}",
        description: "walrus triggered the deploy of shopify/shipit-engine/production to #{@deployment.short_sha}",
        environment_url: "https://shipit.shopify.com",
      ).returns(response)

      @status.create_on_github!
      assert_equal response.id, @status.github_id
      assert_equal response.url, @status.api_url
    end

    test 'description is truncated to character limit' do
      limit = CommitDeploymentStatus::DESCRIPTION_CHARACTER_LIMIT_ON_GITHUB
      deployment = shipit_commit_deployments(:shipit_deploy_second)

      status = deployment.statuses.create!(status: 'success')
      status.stubs(:description).returns('desc' * limit)
      create_status_response = stub(id: 'abcd', url: 'https://github.com/status/abcd')
      status.author.github_api.class.any_instance.expects(:create_deployment_status).with do |_url, _status, kwargs|
        kwargs[:description].size <= limit
      end.returns(create_status_response)

      status.create_on_github!
    end

    test 'includes deployment url when the deployment succeeds' do
      deployment = shipit_commit_deployments(:shipit_deploy_second)

      status = deployment.statuses.create!(status: 'success')
      stack = status.stack
      stack.deploy_url = "stack-deploy-url"
      create_status_response = stub(id: 'abcd', url: 'https://github.com/status/abcd')
      status.author.github_api.class.any_instance.expects(:create_deployment_status).with do |_url, _status, kwargs|
        kwargs[:environment_url] == 'stack-deploy-url'
      end.returns(create_status_response)

      status.create_on_github!
    end
  end
end
