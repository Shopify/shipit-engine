require 'test_helper'

class StacksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
  end

  test "#create creates a Stack, queues a job to setup webhooks and redirects to it" do
    params = {}
    params[:stack] = {
      :repo_name   => "rails",
      :repo_owner  => "rails",
      :environment => "staging",
      :branch      => "staging"
    }

    assert_difference "Stack.count" do
      post :create, params
    end

    assert_redirected_to stack_path(Stack.last)
  end

  test "#destroy behaves correctly" do
    delete :destroy, :id => @stack.to_param
    assert_redirected_to stacks_path
  end

  test "#index before authentication redirects to authentication" do
    Settings.stubs(:authentication).returns(stub(provider: 'google_apps'))

    get :index

    assert_redirected_to "/auth/google_apps"
    assert_equal '/', session[:return_to]
  end

  test "#index when authentication is disabled does not redirect" do
    Settings.stubs(:authentication).returns(false)

    get :index
    assert_response :ok
  end

  test "#index when authentication is successful does not redirect" do
    Settings.stubs(:authentication).returns(stub(provider: 'google_apps'))

    get :index, {}, { user: { email: 'bob@toto.com' } }

    assert_response :ok
  end
end
