require 'test_helper'

module Shipit
  class StacksControllerTest < ActionController::TestCase
    setup do
      @routes = Shipit::Engine.routes
      @stack = shipit_stacks(:shipit)
      session[:user_id] = shipit_users(:walrus).id
    end

    test "validates that Shipit.github_oauth_id is present" do
      Shipit.stubs(github_oauth_credentials: {'secret' => 'abc'})
      get :index
      assert_select "#github_oauth_id .missing"
      assert_select ".missing", count: 1
    end

    test "validates that Shipit.github_oauth_secret is present" do
      Shipit.stubs(github_oauth_credentials: {'id' => 'abc'})
      get :index
      assert_select "#github_oauth_secret .missing"
      assert_select ".missing", count: 1
    end

    test "validates that Shipit.github_api_credentials is present" do
      Shipit.stubs(github_api_credentials: {})
      get :index
      assert_select "#github_api .missing"
      assert_select ".missing", count: 1
    end

    test "validates that Shipit.redis_url is present" do
      Shipit.stubs(redis_url: nil)
      get :index
      assert_select "#redis_url .missing"
      assert_select ".missing", count: 1
    end

    test "validates that Shipit.host is present" do
      Shipit.stubs(host: nil)
      get :index
      assert_select "#host .missing"
      assert_select ".missing", count: 1
    end

    test "GitHub authentication is mandatory" do
      session[:user_id] = nil
      get :index
      assert_redirected_to '/github/auth/github?origin=http%3A%2F%2Ftest.host%2F'
    end

    test "current_user must be a member of at least a Shipit.github_teams" do
      session[:user_id] = shipit_users(:bob).id
      Shipit.stubs(:github_teams).returns([shipit_teams(:cyclimse_cooks), shipit_teams(:shopify_developers)])
      get :index
      assert_response :forbidden
      assert_equal(
        'You must be a member of cyclimse/cooks or shopify/developers to access this application.',
        response.body,
      )
    end

    test "#show is success" do
      get :show, params: {id: @stack.to_param}
      assert_response :ok
    end

    test "#show handles locked stacks without a lock_author" do
      @stack.update!(lock_reason: "I am a lock with no author")
      get :show, params: {id: @stack.to_param}
    end

    test "#show auto-links URLs in lock reason" do
      @stack.update!(lock_reason: 'http://google.com')
      get :show, params: {id: @stack.to_param}
      assert_response :ok
      assert_select 'a[href="http://google.com"]'
    end

    test "#create creates a Stack, queues a job to setup webhooks and redirects to it" do
      assert_difference "Stack.count" do
        post :create, params: {
          stack: {
            repo_name: 'rails',
            repo_owner: 'rails',
            environment: 'staging',
            branch: 'staging',
          },
        }
      end

      assert_redirected_to stack_path(Stack.last)
    end

    test "#create when not valid renders new" do
      assert_no_difference "Stack.count" do
        post :create, params: {stack: {repo_owner: 'some', repo_name: 'owner/path'}}
      end
      assert_response :success
    end

    test "#destroy enqueues a DestroyStackJob" do
      assert_enqueued_with(job: DestroyStackJob, args: [@stack]) do
        delete :destroy, params: {id: @stack.to_param}
      end
      assert_redirected_to stacks_path
    end

    test "#settings is success" do
      get :settings, params: {id: @stack.to_param}
      assert_response :success
    end

    test "#update allows to lock the stack" do
      refute @stack.locked?

      patch :update, params: {id: @stack.to_param, stack: {lock_reason: 'Went out to eat some chips!'}}
      @stack.reload
      assert @stack.locked?
      assert_equal shipit_users(:walrus), @stack.lock_author
    end

    test "#update allows to unlock the stack" do
      @stack.update!(lock_reason: 'Went out to eat some chips!')
      assert @stack.locked?

      patch :update, params: {id: @stack.to_param, stack: {lock_reason: ''}}
      @stack.reload
      refute @stack.locked?
      assert_instance_of AnonymousUser, @stack.lock_author
    end

    test "#refresh queues a RefreshStatusesJob and a GithubSyncJob" do
      request.env['HTTP_REFERER'] = stack_settings_path(@stack)

      assert_enqueued_with(job: RefreshStatusesJob, args: [stack_id: @stack.id]) do
        assert_enqueued_with(job: GithubSyncJob, args: [stack_id: @stack.id]) do
          post :refresh, params: {id: @stack.to_param}
        end
      end

      assert_redirected_to stack_settings_path(@stack)
    end

    test "#sync_webhooks queues #{Stack::REQUIRED_HOOKS.count} SetupGithubHookJob" do
      assert_enqueued_jobs(Stack::REQUIRED_HOOKS.count) do
        post :sync_webhooks, params: {id: @stack.to_param}
      end
      assert_redirected_to stack_settings_path(@stack)
    end

    test "#sync_webhooks displays a flash message" do
      post :sync_webhooks, params: {id: @stack.to_param}
      assert_equal 'Webhooks syncing scheduled', flash[:success]
    end

    test "#clear_git_cache queues a ClearGitCacheJob" do
      assert_enqueued_with(job: ClearGitCacheJob, args: [@stack]) do
        post :clear_git_cache, params: {id: @stack.to_param}
      end
      assert_redirected_to stack_settings_path(@stack)
    end

    test "#clear_git_cache displays a flash message" do
      post :clear_git_cache, params: {id: @stack.to_param}
      assert_equal 'Git Cache clearing scheduled', flash[:success]
    end

    test "#update redirects to return_to parameter" do
      patch :update, params: {id: @stack.to_param, stack: {ignore_ci: false}, return_to: stack_path(@stack)}
      assert_redirected_to stack_path(@stack)
    end

    test "#lookup redirects to the canonical URL" do
      get :lookup, params: {id: @stack.id}
      assert_redirected_to stack_path(@stack)
    end

    test "#create does not create stack with invalid deploy_url" do
      post :create, params: {
        stack: {
          repo_name: 'rails',
          repo_owner: 'rails',
          environment: 'staging',
          branch: 'staging',
          deploy_url: 'Javascript:alert(1);',
        },
      }
      assert_response :success
      assert_equal 'Deploy url is invalid', flash[:warning]
    end
  end
end
