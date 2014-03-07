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

  test ":callback redirects to session[:redirect_to] if auth is ok" do
    Settings.stubs(:authentication).returns(stub(provider: :google_apps))
    @request.env['omniauth.auth'] = { 'info' => { 'email' => 'bob@toto.com' } }
    stack = stacks(:shipit)

    post :callback, { provider: :google_apps }, { return_to: stack_path(stack) }
    assert_redirected_to stack_path(stack)
  end

  test ":callback redirects to session[:redirect_to] if auth isn't required" do
    Settings.stubs(:authentication).returns(false)
    @request.env['omniauth.auth'] = nil

    stack = stacks(:shipit)

    post :callback, { provider: :google_apps }, { return_to: stack_path(stack) }
    assert_redirected_to stack_path(stack)
  end
end
