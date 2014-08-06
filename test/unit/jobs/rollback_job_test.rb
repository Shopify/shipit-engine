require 'test_helper'

class RollbackJobTest < ActiveSupport::TestCase

  setup do
    @job = RollbackJob.new
    @deploy = deploys(:shipit_complete)
  end

  test "#perform fetch commits from the API" do
    @job.stubs(:capture)
    @commands = stub(:commands)
    Deploy.expects(:find).with(@deploy.id).returns(@deploy)
    DeployCommands.expects(:new).with(@deploy).returns(@commands)

    @commands.expects(:fetch).once
    @commands.expects(:clone).once
    @commands.expects(:checkout).with(@deploy.until_commit).once
    @commands.expects(:install_dependencies).returns([]).once
    @commands.expects(:deploy).with(@deploy.until_commit).returns([]).once

    @deploy.expects(:clear_working_directory)

    @job.perform(deploy_id: @deploy.id)
  end

  test "marks deploy as rollback" do
    Dir.stubs(:chdir).yields
    DeployCommands.any_instance.stubs(:deploy).returns([])
    @job.stubs(:capture)

    @job.perform(deploy_id: @deploy.id)
    assert_equal 'rollback', @deploy.reload.status
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

  test "bail out if deploy is not complete" do
    @deploy = deploys(:shipit_running)
    @job.expects(:capture).never
    @job.perform(deploy_id: @deploy.id)
  end

  test "mark deploy as error if a command timeout" do
    Timeout.expects(:timeout).raises(Timeout::Error.new)
    Command.any_instance.expects(:terminate!)
    assert_raises(Timeout::Error) do
      @job.perform(deploy_id: @deploy.id)
    end
    assert @deploy.reload.error?
  end

end
