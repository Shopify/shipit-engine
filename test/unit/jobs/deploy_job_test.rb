require 'test_helper'

class DeployJobTest < ActiveSupport::TestCase

  setup do
    @job = DeployJob.new
    @deploy = deploys(:shipit_pending)
  end

  test "#perform fetch commits from the API" do
    @job.stubs(:capture)
    @commands = stub(:commands)
    DeployCommands.expects(:new).with(@deploy).returns(@commands)

    @commands.expects(:fetch).once
    @commands.expects(:clone).once
    @commands.expects(:checkout).with(@deploy.until_commit).once
    @commands.expects(:bundle_install).once
    @commands.expects(:deploy).with(@deploy.until_commit).once

    @job.perform(deploy_id: @deploy.id)
  end

  test "#perform raises an error" do
    @job.expects(:capture).raises("some error")
    assert_raise(RuntimeError) do
      @job.perform(deploy_id: @deploy.id)
    end
    assert_equal 'failed', @deploy.reload.status
  end
end
