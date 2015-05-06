require 'test_helper'

class GithubAuthenticationControllerTest < ActionController::TestCase
  test ":callback can sign in to github" do
    @request.env['omniauth.auth'] = {info:  {nickname: 'shipit'}}
    github_user = mock('Sawyer User')
    Shipster.github_api.stubs(:user).returns(github_user)
    User.expects(:find_or_create_from_github).with(github_user).returns(stub(id: 44))

    get :callback
  end
end
