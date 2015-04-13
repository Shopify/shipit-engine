require 'test_helper'

class AuthenticationControllerTest < ActionController::TestCase
  setup do
    Shipit.stubs(:authentication).returns('provider' => 'google_oauth2')
  end

  test ":callback renders a snowman if not authenticated and authentication is required" do
    @request.env['omniauth.auth'] = nil

    post :callback, provider: :google_oauth2
    assert_response :ok
    assert_select "h3", "Snowman says No"
    assert_select ".sidebar", false
  end

  test ":callback redirects to params[:origin] if auth is ok" do
    stack = stacks(:shipit)
    @controller.expects(:reset_session)
    @request.env['omniauth.auth'] = {'info' => {'email' => 'bob@toto.com'}}
    @request.env['omniauth.origin'] = stack_path(stack)

    post :callback, provider: :google_apps
    assert_redirected_to stack_path(stack)
  end

  test ":callback refuses authentication if the email domain doesn't match" do
    stack = stacks(:shipit)
    Shipit.stubs(:authentication).returns('provider' => 'google_oauth2', 'email_domain' => 'shopify.com')
    @request.env['omniauth.auth'] = {'info' => {'email' => 'bob@toto.com'}, 'provider' => 'google_oauth2'}
    @request.env['omniauth.origin'] = stack_path(stack)

    post :callback, provider: :google_apps
    assert_redirected_to stack_path(stack)
    refute session[:authenticated]
  end

  test ":callback can sign in to github" do
    @controller.expects(:reset_session)

    @request.env['omniauth.auth'] = {provider: 'github', info:  {nickname: 'shipit'}}
    github_user = mock('Sawyer User')
    Shipit.github_api.stubs(:user).returns(github_user)
    User.expects(:find_or_create_from_github).with(github_user).returns(stub(id: 44))

    get :callback, provider: 'github'
  end
end
