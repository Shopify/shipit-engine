require 'test_helper'

class StacksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
    session[:user_id] = users(:walrus).id
  end

  test "GitHub authentication is mandatory" do
    session[:user_id] = nil
    get :index
    assert_redirected_to authentication_path(:github, origin: root_url)
  end

  test "mandatory GitHub authentication can be disabled" do
    session[:user_id] = nil
    Shipit.stubs(:github).returns('optional' => true)
    get :index
    assert_response :ok
  end

  test "#show is success" do
    get :show, id: @stack.to_param
    assert_response :ok
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

  test "#create when not valid renders new" do
    params = {
      stack: {
        repo_owner:  "some",
        repo_name:   "owner/path" # no good
      }
    }

    assert_no_difference "Stack.count" do
      post :create, params
    end

    assert_template :new
  end

  test "#destroy behaves correctly" do
    delete :destroy, :id => @stack.to_param
    assert_redirected_to stacks_path
  end

  test "#index before authentication redirects to authentication" do
    Shipit.stubs(:authentication).returns('provider' => 'google_apps')

    get :index

    assert_redirected_to "/auth/google_apps?origin=%2F"
  end

  test "#index when authentication is disabled does not redirect" do
    Shipit.stubs(:authentication).returns(false)

    get :index
    assert_response :ok
  end

  test "#index when authentication is successful does not redirect" do
    Shipit.stubs(:authentication).returns('provider' => 'google_apps')

    get :index, {}, { authenticated: true }

    assert_response :ok
  end

  test "#settings is success" do
    get :settings, id: @stack.to_param
    assert_response :success
  end

  test "#sync_commits queues a GithubSyncJob" do
    Resque.expects(:enqueue).with(GithubSyncJob, stack_id: @stack.id)
    post :sync_commits, id: @stack.to_param
    assert_redirected_to stack_settings_path(@stack)
  end

  test "#refresh_statuses queues a RefreshStatusesJob" do
    Resque.expects(:enqueue).with(RefreshStatusesJob, stack_id: @stack.id)
    post :refresh_statuses, id: @stack.to_param
    assert_redirected_to stack_settings_path(@stack)
  end

  test "#sync_webhooks queues a GithubSetupWeebhookJob" do
    Resque.expects(:enqueue).with(GithubSetupWebhooksJob, stack_id: @stack.id)
    post :sync_webhooks, id: @stack.to_param
    assert_redirected_to stack_settings_path(@stack)
  end

  test "#clear_git_cache queues a ClearGitCacheJob" do
    Resque.expects(:enqueue).with(ClearGitCacheJob, stack_id: @stack.id)
    post :clear_git_cache, id: @stack.to_param
    assert_redirected_to stack_settings_path(@stack)
  end

  test "#fixit queues GithubSyncJob, RefreshStatusesJob, GithubSetupWebhooksJob and ClearGitCacheJob" do
    Resque.expects(:enqueue).with(GithubSyncJob, stack_id: @stack.id)
    Resque.expects(:enqueue).with(RefreshStatusesJob, stack_id: @stack.id)
    Resque.expects(:enqueue).with(GithubSetupWebhooksJob, stack_id: @stack.id)
    Resque.expects(:enqueue).with(ClearGitCacheJob, stack_id: @stack.id)

    post :fixit, id: @stack.to_param
    assert_redirected_to stack_settings_path(@stack)
  end
end
