require 'test_helper'
require 'tmpdir'

class CacheDeploySpecJobTest < ActiveSupport::TestCase
  setup do
    @stack = stacks(:shipit)
    @last_commit = commits(:fifth)
    @job = CacheDeploySpecJob.new
  end

  test "#perform checkout the repository to the last recorded commit and cache the deploy spec" do
    @stack.update!(cached_deploy_spec: DeploySpec.new('review' => {'checklist' => %w(foo bar)}))

    dir = Pathname(Dir.tmpdir)
    StackCommands.any_instance.expects(:with_temporary_working_directory).with(commit: @last_commit).yields(dir)

    assert_equal %w(foo bar), @stack.checklist
    @job.perform(@stack)
    assert_equal [], @stack.reload.checklist
  end
end
