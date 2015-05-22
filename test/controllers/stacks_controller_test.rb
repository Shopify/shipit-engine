require 'test_helper'

class StacksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
    session[:user_id] = users(:walrus).id
  end

  test "validates that Shipit.github_oauth_id is present" do
    Shipit.stubs(github_oauth_credentials: {'secret' => 'abc'})
    get :index
    assert_template 'missing_settings'
    assert_select "#github_oauth_id .missing"
    assert_select ".missing", count: 1
  end

  test "validates that Shipit.github_oauth_secret is present" do
    Shipit.stubs(github_oauth_credentials: {'id' => 'abc'})
    get :index
    assert_template 'missing_settings'
    assert_select "#github_oauth_secret .missing"
    assert_select ".missing", count: 1
  end

  test "validates that Shipit.github_api_credentials is present" do
    Shipit.stubs(github_api_credentials: {})
    get :index
    assert_template 'missing_settings'
    assert_select "#github_api .missing"
    assert_select ".missing", count: 1
  end

  test "validates that Shipit.redis_url is present" do
    Shipit.stubs(redis_url: nil)
    get :index
    assert_template 'missing_settings'
    assert_select "#redis_url .missing"
    assert_select ".missing", count: 1
  end

  test "validates that Shipit.host is present" do
    Shipit.stubs(host: nil)
    get :index
    assert_template 'missing_settings'
    assert_select "#host .missing"
    assert_select ".missing", count: 1
  end

  test "GitHub authentication is mandatory" do
    session[:user_id] = nil
    get :index
    assert_redirected_to github_authentication_path(origin: root_url)
  end

  test "current_user must be a member of Shipit.github_team" do
    Shipit.stubs(:github_team).returns(teams(:cyclimse_cooks))
    get :index
    assert_response :forbidden
    assert_equal 'You must be a member of cyclimse/cooks to access this application.', response.body
  end

  test "#show is success" do
    get :show, id: @stack.to_param
    assert_response :ok
  end

  test "#create creates a Stack, queues a job to setup webhooks and redirects to it" do
    params = {}
    params[:stack] = {
      repo_name: "rails",
      repo_owner: "rails",
      environment: "staging",
      branch: "staging",
    }

    assert_difference ->{ Stack.count } do
      post :create, params
    end

    assert_redirected_to stack_path(Stack.last)
  end

  test "#create when not valid renders new" do
    assert_no_difference ->{ Stack.count } do
      post :create, stack: {repo_owner: 'some', repo_name: 'owner/path'}
    end

    assert_template :new
  end

  test "#destroy enqueues a DestroyStackJob" do
    assert_enqueued_with(job: DestroyStackJob, args: [@stack]) do
      delete :destroy, id: @stack.to_param
    end
    assert_redirected_to stacks_path
  end

  test "#settings is success" do
    get :settings, id: @stack.to_param
    assert_response :success
  end

  test "#update allows to lock the stack" do
    refute @stack.locked?

    patch :update, id: @stack.to_param, stack: {lock_reason: 'Went out to eat some chips!'}
    @stack.reload
    assert @stack.locked?
    assert_equal users(:walrus), @stack.lock_author
  end

  test "#update allows to unlock the stack" do
    @stack.update!(lock_reason: 'Went out to eat some chips!')
    assert @stack.locked?

    patch :update, id: @stack.to_param, stack: {lock_reason: ''}
    @stack.reload
    refute @stack.locked?
    assert_nil @stack.lock_author
  end

  test "#refresh queues a RefreshStatusesJob and a GithubSyncJob" do
    request.env['HTTP_REFERER'] = stack_settings_path(@stack)

    assert_enqueued_with(job: RefreshStatusesJob, args: [stack_id: @stack.id]) do
      assert_enqueued_with(job: GithubSyncJob, args: [stack_id: @stack.id]) do
        post :refresh, id: @stack.to_param
      end
    end

    assert_redirected_to stack_settings_path(@stack)
  end

  test "#sync_webhooks queues #{Stack::REQUIRED_HOOKS.count} SetupGithubHookJob" do
    assert_enqueued_jobs(Stack::REQUIRED_HOOKS.count) do
      post :sync_webhooks, id: @stack.to_param
    end
    assert_redirected_to stack_settings_path(@stack)
  end

  test "#clear_git_cache queues a ClearGitCacheJob" do
    assert_enqueued_with(job: ClearGitCacheJob, args: [@stack]) do
      post :clear_git_cache, id: @stack.to_param
    end
    assert_redirected_to stack_settings_path(@stack)
  end
end
