# frozen_string_literal: true

require 'test_helper'

module Shipit
  class CacheDeploySpecJobTest < ActiveSupport::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @last_commit = @stack.commits.last
      @job = CacheDeploySpecJob.new
    end

    test "#perform checkout the repository to the last recorded commit and cache the deploy spec" do
      @stack.update!(cached_deploy_spec: DeploySpec.new('review' => { 'checklist' => %w[foo bar] }))

      dir = Pathname(Dir.tmpdir)
      StackCommands.any_instance.expects(:with_temporary_working_directory)
                   .with(commit: @last_commit, recursive: false).yields(dir)

      assert_equal %w[foo bar], @stack.checklist
      @job.perform(@stack)
      assert_equal [], @stack.reload.checklist
    end

    test "the dedupe lock expiration covers the job runtime" do
      assert_operator CacheDeploySpecJob.timeout, :>, BackgroundJob::Unique::DEFAULT_TIMEOUT
      assert_equal 15.minutes.to_i, CacheDeploySpecJob.timeout
    end

    test "a duplicate job for the same stack is dropped while the lock is held" do
      job = CacheDeploySpecJob.new(@stack)
      duplicate = CacheDeploySpecJob.new(@stack)
      duplicate_ran = false

      job.acquire_lock do
        duplicate.acquire_lock do
          duplicate_ran = true
        end
      end

      refute duplicate_ran, "duplicate should have been dropped, not executed"
    end
  end
end
