require 'test_helper'

class GithubDeployStatusJobTest < ActiveSupport::TestCase

  setup do
    @job = GithubDeployStatusJob.new
    @deploy = deploys(:shipit_running)
  end

  test "it simply call push_github_status with the received status" do
    Deploy.expects(:find).with(@deploy.id).returns(@deploy)
    @deploy.expects(:push_github_status).with('success')

    @job.perform(deploy_id: @deploy.id, status: 'success')
  end

end
