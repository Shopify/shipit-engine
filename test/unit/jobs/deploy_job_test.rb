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
    @commands.expects(:install_dependencies).returns([]).once
    @commands.expects(:deploy).with(@deploy.until_commit).returns([]).once

    @job.perform(deploy_id: @deploy.id)
  end

  test "marks deploy as successful" do
    Dir.stubs(:chdir).yields
    DeployCommands.any_instance.stubs(:deploy).returns([])
    @job.stubs(:capture)

    @job.perform(deploy_id: @deploy.id)
    assert_equal 'success', @deploy.reload.status
  end

  test "marks deploy as `error` if any application error is raised" do
    @job.expects(:capture).raises("some error")
    assert_raise(RuntimeError) do
      @job.perform(deploy_id: @deploy.id)
    end
    assert_equal 'error', @deploy.reload.status
  end

  test "marks deploy as `failed` if a command exit with an error code" do
    @job.expects(:capture).raises(Command::Error.new('something'))
    @job.perform(deploy_id: @deploy.id)
    assert_equal 'failed', @deploy.reload.status
  end

  test "bail out if deploy is not pending" do
    @deploy.run!
    @job.expects(:capture).never
    @job.perform(deploy_id: @deploy.id)
  end

end
