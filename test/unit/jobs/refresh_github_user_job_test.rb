require 'test_helper'

class RefreshGithubUserJobTest < ActiveSupport::TestCase
  setup do
    @user = users(:walrus)
    @job = RefreshGithubUserJob
  end

  test "#perform call #refresh_from_github! on the provided user" do
    User.expects(:find).with(@user.id).returns(@user)
    @user.expects(:refresh_from_github!)

    @job.perform(user_id: @user.id)
  end
end
