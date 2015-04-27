require 'test_helper'

class RefreshGithubUserJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:walrus)
    @job = RefreshGithubUserJob.new
  end

  test "#perform call #refresh_from_github! on the provided user" do
    @user.expects(:refresh_from_github!)
    @job.perform(@user)
  end
end
