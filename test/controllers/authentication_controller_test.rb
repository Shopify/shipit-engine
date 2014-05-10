require 'test_helper'

class AuthenticationControllerTest < ActionController::TestCase
  test ":callback renders a snowman if not authenticated and authentication is required" do
    Settings.stubs(:authentication).returns(stub(provider: :google_apps))
    @request.env['omniauth.auth'] = nil

    post :callback, provider: :google_apps
    assert_response :ok
    assert_select "h3", "Snowman says No"
    assert_select ".sidebar", false
  end

  test ":callback redirects to params[:origin] if auth is ok" do
    Settings.stubs(:authentication).returns(stub(provider: :google_apps))
    @controller.expects(:reset_session)
    @request.env['omniauth.auth'] = { 'info' => { 'email' => 'bob@toto.com' } }
    stack = stacks(:shipit)

    post :callback, provider: :google_apps, origin: stack_path(stack)
    assert_redirected_to stack_path(stack)
  end

  test ":callback can sign in to github" do
    Settings.stubs(:authentication).returns(stub(provider: :google_apps))
    @controller.expects(:reset_session)

    @request.env['omniauth.auth'] = { provider: 'github', info:  { nickname: 'shipit' } }
    github_user = mock('Sawyer User')
    Shipit.github_api.stubs(:user).returns(github_user)
    User.expects(:find_or_create_from_github).with(github_user).returns(stub(id: 44))

    get :callback, provider: 'github'
  end
end
