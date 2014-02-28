require 'test_helper'

class DeployJobTest < ActiveSupport::TestCase

  setup do
    @job = DeployJob.new
    @deploy = deploys(:shipit_pending)
  end

  test "#perform fetch commits from the API" do
    @job.stubs(:capture)
    @commands = stub(:commands)
    Deploy.expects(:find).with(@deploy.id).returns(@deploy)
    StackCommands.expects(:new).with(@deploy.stack).returns(@commands)

    @commands.expects(:fetch).once
    @commands.expects(:clone).with(@deploy).once
    Dir.expects(:chdir).with(@deploy.working_directory).once.yields
    @commands.expects(:checkout).with(@deploy.until_commit).once
    @commands.expects(:deploy).with(@deploy.until_commit).once

    @job.perform(deploy_id: @deploy.id)
  end

  # TODO: test this job better

end
