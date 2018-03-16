require 'test_helper'

module Shipit
  class PerformTaskJobTest < ActiveSupport::TestCase
    setup do
      @job = PerformTaskJob.new
      @deploy = shipit_deploys(:shipit_pending)
      @stack = shipit_stacks(:shipit)
    end

    test "#perform fetch commits from the API" do
      @job.stubs(:capture!)
      @job.stubs(:capture)
      @commands = stub(:commands)
      Commands.expects(:for).with(@deploy).returns(@commands)

      @commands.expects(:fetched?).once.returns(false)
      @commands.expects(:fetch).once
      @commands.expects(:clone).once
      @commands.expects(:checkout).with(@deploy.until_commit).once
      @commands.expects(:install_dependencies).returns([]).once
      @commands.expects(:perform).returns([]).once

      @commands.expects(:clear_working_directory)

      @job.perform(@deploy)
    end

    test "#perform enqueues a FetchDeployedRevisionJob" do
      Dir.stubs(:chdir).yields
      DeployCommands.any_instance.expects(:perform).returns([])
      @job.stubs(:capture!)

      assert_enqueued_with(job: FetchDeployedRevisionJob, args: [@deploy.stack]) do
        @job.perform(@deploy)
      end
    end

    test "marks deploy as successful" do
      Dir.stubs(:chdir).yields
      DeployCommands.any_instance.expects(:perform).returns([])
      @job.stubs(:capture!)

      @job.perform(@deploy)
      assert_equal 'success', @deploy.reload.status
    end

    test "marks deploy as `error` if any application error is raised" do
      @job.expects(:capture!).raises("some error")
      assert_nothing_raised do
        @job.perform(@deploy)
      end
      assert_equal 'error', @deploy.reload.status
      assert_includes @deploy.chunk_output, 'RuntimeError: some error'
    end

    test "marks deploy as `failed` if a command exit with an error code" do
      @job.expects(:capture!).at_least_once.raises(Command::Error.new('something'))
      @job.perform(@deploy)
      assert_equal 'failed', @deploy.reload.status
    end

    test "bail out if deploy is not pending" do
      @deploy.run!
      @job.expects(:capture!).never
      @job.expects(:capture!).never
      @job.perform(@deploy)
    end

    test "mark deploy as error an unexpected exception is raised" do
      Command.any_instance.expects(:stream!).at_least_once.raises(Command::Denied)

      @job.perform(@deploy)

      assert_equal 'failed', @deploy.reload.status
      assert_includes @deploy.chunk_output, 'Denied'
    end

    test "mark deploy as timedout if a command timeout" do
      Command.any_instance.expects(:stream!).at_least_once.raises(Command::TimedOut)

      @job.perform(@deploy)

      assert_equal 'timedout', @deploy.reload.status
      assert_includes @deploy.chunk_output, 'TimedOut'
    end

    test "mark deploy as timedout if a command exit in one of the codes in Shipit.timeout_exit_codes" do
      previous_exit_codes = Shipit.timeout_exit_codes
      begin
        Shipit.timeout_exit_codes = [70].freeze

        Command.any_instance.expects(:stream!).at_least_once.raises(Command::Failed.new('Blah', 70))

        @job.perform(@deploy)

        assert_equal 'timedout', @deploy.reload.status
      ensure
        Shipit.timeout_exit_codes = previous_exit_codes
      end
    end

    test "records stack support for rollbacks and fetching deployed revision" do
      @job.stubs(:capture!)
      @commands = stub(:commands)
      @commands.stubs(:fetched?).returns([])
      @commands.stubs(:fetch).returns([])
      @commands.stubs(:clone).returns([])
      @commands.stubs(:checkout).returns([])
      @commands.stubs(:install_dependencies).returns([])
      @commands.stubs(:perform).returns([])
      DeployCommands.expects(:new).with(@deploy).returns(@commands)
      @commands.stubs(:clear_working_directory)

      @stack.update!(cached_deploy_spec: DeploySpec.new({}))

      refute @stack.supports_rollback?
      refute @stack.supports_fetch_deployed_revision?

      @job.perform(@deploy)
      @stack.reload

      DeploySpec.any_instance.expects(:supports_fetch_deployed_revision?).returns(true)
      DeploySpec.any_instance.expects(:supports_rollback?).returns(true)

      assert @stack.supports_rollback?
      assert @stack.supports_fetch_deployed_revision?
    end
  end
end
