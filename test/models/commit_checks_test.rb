# typed: false
require 'test_helper'
require 'tmpdir'

module Shipit
  class CommitChecksTest < ActiveSupport::TestCase
    setup do
      @commit = shipit_commits(:fifth)
      @checks = @commit.checks
    end

    test "#schedule schedule the checks if output is missing" do
      assert_enqueued_with(job: PerformCommitChecksJob, args: [commit: @commit]) do
        @checks.schedule
      end
    end

    test "#schedule just returns the current output if present" do
      schedule_checks

      assert_no_enqueued_jobs do
        @checks.schedule
      end
    end

    test "it is considered finished if the status is `success`, `failed` or `error`" do
      @checks.status = 'success'
      assert @checks.finished?

      @checks.status = 'failed'
      assert @checks.finished?

      @checks.status = 'error'
      assert @checks.finished?

      @checks.status = 'scheduled'
      refute @checks.finished?

      @checks.status = 'running'
      refute @checks.finished?

      @checks.status = nil
      refute @checks.finished?
    end

    test "#status is `scheduled` when the job is triggered" do
      schedule_checks
      assert_equal 'scheduled', @checks.status
    end

    test "#write append the string in redis" do
      CommitChecks.new(@commit).write('foo')
      CommitChecks.new(@commit).write('bar')
      assert_equal 'foobar', CommitChecks.new(@commit).output
    end

    test "#output allow to retreive only a slice of the output" do
      @checks.write('foobar')
      assert_equal 'bar', @checks.output(since: 3)
    end

    test "#run execute the shell commands and update the status and output" do
      StackCommands.any_instance.expects(:with_temporary_working_directory).yields(Pathname.new(Dir.tmpdir))
      DeploySpec::FileSystem.any_instance.expects(:dependencies_steps).returns(['echo dependencies'])
      DeploySpec::FileSystem.any_instance.expects(:review_checks).returns(['echo review'])

      @checks.run
      lines = [
        '$ echo dependencies',
        'dependencies',
        '',
        '$ echo review',
        'review',
        '',
      ]
      assert_equal 'success', @checks.status
      assert_equal lines, @checks.output.lines.map(&:strip)
    end

    private

    def schedule_checks
      CommitChecks.new(@commit).schedule
    end
  end
end
