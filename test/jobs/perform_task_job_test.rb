# frozen_string_literal: true
require 'test_helper'

module Shipit
  class PerformTaskJobTest < ActiveSupport::TestCase
    class FakeSuccessfulCommand
      def run
      end

      def success?
        true
      end
    end

    setup do
      @job = PerformTaskJob.new
      @deploy = shipit_deploys(:shipit_pending)
      @stack = shipit_stacks(:shipit)
    end

    test "#perform fetch commits from the API" do
      @job.stubs(:capture!)
      @job.stubs(:capture)
      @commands = stub
      Commands.expects(:for).with(@deploy).returns(@commands)

      @commands.expects(:fetched?).once.returns(FakeSuccessfulCommand.new)
      @commands.expects(:clone).returns([]).once
      @commands.expects(:checkout).with(@deploy.until_commit).once
      @commands.expects(:install_dependencies).returns([]).once
      @commands.expects(:perform).returns([]).once

      @commands.expects(:clear_working_directory)

      @job.perform(@deploy)
    end

    test "#perform enqueues a FetchDeployedRevisionJob" do
      @deploy.stack.expects(:release_status?).at_least_once.returns(false)
      Dir.stubs(:chdir).yields
      DeployCommands.any_instance.expects(:perform).returns([])
      @job.stubs(:capture!)

      assert_enqueued_with(job: FetchDeployedRevisionJob, args: [@deploy.stack]) do
        @job.perform(@deploy)
      end
    end

    test "marks deploy as successful" do
      @deploy.stack.expects(:release_status?).at_least_once.returns(false)
      Dir.stubs(:chdir).yields
      DeployCommands.any_instance.expects(:perform).returns([])
      @job.stubs(:capture!)

      assert_equal 'pending', @deploy.status
      @job.perform(@deploy)
      assert_equal 'success', @deploy.reload.status
    end

    test "marks deploy as validating when the stack has a positive release status delay" do
      @deploy = shipit_tasks(:canaries_running)
      @deploy.update_column(:status, 'pending')

      Dir.stubs(:chdir).yields
      DeployCommands.any_instance.expects(:perform).returns([])
      @job.stubs(:capture!)

      assert_equal 'pending', @deploy.status
      @job.perform(@deploy)
      assert_equal 'validating', @deploy.reload.status
    end

    test "marks deploy as successful when the stack has no release status delay" do
      @deploy = shipit_tasks(:canaries_running)
      @deploy.update_column(:status, 'pending')
      @deploy.stack.expects(:release_status_delay).at_least_once.returns(Duration.parse(0))

      Dir.stubs(:chdir).yields
      DeployCommands.any_instance.expects(:perform).returns([])
      @job.stubs(:capture!)

      assert_equal 'pending', @deploy.status
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

        assert_equal('timedout', @deploy.reload.status)
      ensure
        Shipit.timeout_exit_codes = previous_exit_codes
      end
    end

    test "records stack support for rollbacks and fetching deployed revision" do
      @job.stubs(:capture!)
      @commands = stub
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

    test "writes complex lines for git fetch operations" do
      stream_output = "Cloning into 'test'...\r\nremote: Enumerating objects: 16, done.\e[K\r\nremote: Counting objects:   6% (1/16)\e[K\rremote: Counting objects:  12% (2/16)\e[K\rremote: Counting objects:  18% (3/16)\e[K\rremote: Counting objects:  25% (4/16)\e[K\rremote: Counting objects:  31% (5/16)\e[K\rremote: Counting objects:  37% (6/16)\e[K\rremote: Counting objects:  43% (7/16)\e[K\rremote: Counting objects:  50% (8/16)\e[K\rremote: Counting objects:  56% (9/16)\e[K\rremote: Counting objects:  62% (10/16)\e[K\rremote: Counting objects:  68% (11/16)\e[K\rremote: Counting objects:  75% (12/16)\e[K\rremote: Counting objects:  81% (13/16)\e[K\rremote: Counting objects:  87% (14/16)\e[K\rremote: Counting objects:  93% (15/16)\e[K\rremote: Counting objects: 100% (16/16)\e[K\rremote: Counting objects: 100% (16/16), done.\e[K\r\nremote: Compressing objects:   8% (1/12)\e[K\rremote: Compressing objects:  16% (2/12)\e[K\rremote: Compressing objects:  25% (3/12)\e[K\rremote: Compressing objects:  33% (4/12)\e[K\rremote: Compressing objects:  41% (5/12)\e[K\rremote: Compressing obje"

      @commands = stub
      Commands.expects(:for).with(@deploy).returns(@commands)

      fetched_stub = stub
      fetched_stub.expects(:run).twice
      fetched_stub.expects(:success?).returns(false).twice
      @commands.expects(:fetched?).returns(fetched_stub).twice

      fake_command = stub
      fake_command.stubs(:start)
      fake_command.stubs(:pid).returns(123)
      fake_command.stubs(:success?)
      fake_command.stubs(:stream!).yields(stream_output)
      @commands.expects(:fetch).returns(fake_command)

      fake_checkout = stub
      fake_checkout.stubs(:start)
      fake_checkout.stubs(:pid).returns(456)
      fake_checkout.stubs(:success?)
      fake_checkout.stubs(:stream!)
      @commands.expects(:checkout).with(@deploy.until_commit).returns(fake_checkout)

      @commands.expects(:clone).returns([])
      @commands.expects(:install_dependencies).returns([]).once
      @commands.expects(:perform).returns([]).once
      @commands.expects(:clear_working_directory)

      expected_output = [
        "$ #{fake_command}\npid: 123\n",
        "Cloning into 'test'...\n",
        "\n",
        "remote: Enumerating objects: 16, done.\n",
        "\n",
        "remote: Counting objects:   6% (1/16)\n",
        "remote: Counting objects:  12% (2/16)\n",
        "remote: Counting objects:  18% (3/16)\n",
        "remote: Counting objects:  25% (4/16)\n",
        "remote: Counting objects:  31% (5/16)\n",
        "remote: Counting objects:  37% (6/16)\n",
        "remote: Counting objects:  43% (7/16)\n",
        "remote: Counting objects:  50% (8/16)\n",
        "remote: Counting objects:  56% (9/16)\n",
        "remote: Counting objects:  62% (10/16)\n",
        "remote: Counting objects:  68% (11/16)\n",
        "remote: Counting objects:  75% (12/16)\n",
        "remote: Counting objects:  81% (13/16)\n",
        "remote: Counting objects:  87% (14/16)\n",
        "remote: Counting objects:  93% (15/16)\n",
        "remote: Counting objects: 100% (16/16)\n",
        "remote: Counting objects: 100% (16/16), done.\n",
        "\n",
        "remote: Compressing objects:   8% (1/12)\n",
        "remote: Compressing objects:  16% (2/12)\n",
        "remote: Compressing objects:  25% (3/12)\n",
        "remote: Compressing objects:  33% (4/12)\n",
        "remote: Compressing objects:  41% (5/12)\n",
        "remote: Compressing obje\n",
        "\n",
        "$ #{fake_checkout}\npid: 456\n",
        "\n",
        "\nCompleted successfully\n",
      ]

      with_fake_writer(@deploy) do |buffer|
        @job.perform(@deploy)

        assert_equal(expected_output, buffer)
      end
    end

    private

    def with_fake_writer(command)
      original = command.method(:write)

      def command.write(args)
        FakeWriter.write(args)
      end

      yield(FakeWriter.buffer)
    ensure
      command.singleton_class.define_method(:write) do |args|
        original.call(args)
      end

      FakeWriter.reset!
    end

    class FakeWriter
      class << self
        def buffer
          @buffer ||= []
        end

        def reset!
          @buffer = []
        end

        def write(line)
          buffer << line
        end
      end
    end
    private_constant(:FakeWriter)
  end
end
