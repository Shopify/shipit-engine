# frozen_string_literal: true
require 'test_helper'

module Shipit
  class StacksControllerTest < ActionController::TestCase
    setup do
      @routes = Shipit::Engine.routes
      @stack = shipit_stacks(:shipit)
      session[:user_id] = shipit_users(:walrus).id
    end

    test "validates that Shipit.github is present" do
      Rails.application.credentials.stubs(:github).returns(nil)
      get :index
      assert_select "#github_app .missing"
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

    test "users which require a fresh login are redirected" do
      user = shipit_users(:walrus)
      user.update!(github_access_token: 'some_legacy_value')
      assert_predicate user, :requires_fresh_login?

      get :index

      assert_redirected_to '/github/auth/github?origin=http%3A%2F%2Ftest.host%2F'
      assert_nil session[:user_id]
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

    test "#index list all stacks" do
      get :index, params: { show_archived: true }
      assert_response :ok
      assert_select ".stack", count: Stack.count
    end

    test "#index list all not archived stacks" do
      get :index
      assert_response :ok
      assert_select ".stack", count: Stack.not_archived.count
    end

    test "#index list a repo stacks if the :repo params is passed" do
      repo = shipit_repositories(:shipit)
      get :index, params: { repo: repo.full_name }
      assert_response :ok
      assert_select ".stack", count: repo.stacks.count
    end

    test "#show is success" do
      get :show, params: { id: @stack.to_param }
      assert_response :ok
    end

    test "#show with faulty and validating deploys is success" do
      get :show, params: { id: shipit_stacks(:shipit_canaries).to_param }
      assert_response :ok
    end

    test "#show with a single CheckRun is successful" do
      @stack = shipit_stacks(:check_runs)
      assert_not_equal 0, CheckRun.where(stack_id: @stack.id).count

      get :show, params: { id: @stack.to_param }
      assert_response :ok
    end

    test "#show handles locked stacks without a lock_author" do
      @stack.update!(lock_reason: "I am a lock with no author")
      get :show, params: { id: @stack.to_param }
    end

    test "#show auto-links URLs in lock reason" do
      @stack.update!(lock_reason: 'http://google.com')
      get :show, params: { id: @stack.to_param }
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
        post :create, params: { stack: { repo_owner: 'some', repo_name: 'owner/path' } }
      end
      assert_response :success
    end

    test "#destroy enqueues a DestroyStackJob" do
      assert_enqueued_with(job: DestroyStackJob, args: [@stack]) do
        delete :destroy, params: { id: @stack.to_param }
      end
      assert_redirected_to stacks_path
    end

    test "#settings is success" do
      get :settings, params: { id: @stack.to_param }
      assert_response :success
    end

    test "#statistics is success" do
      get :statistics, params: { id: @stack.to_param }
      assert_response :success
    end

    test "#statistics redirects to #show if no deploys are present" do
      @stack.deploys.destroy_all
      get :statistics, params: { id: @stack.to_param }
      assert_redirected_to stack_path(@stack)
    end

    test "#update allows to lock the stack" do
      refute @stack.locked?

      patch :update, params: { id: @stack.to_param, stack: { lock_reason: 'Went out to eat some chips!' } }
      @stack.reload
      assert @stack.locked?
      assert_equal shipit_users(:walrus), @stack.lock_author
    end

    test "#update allows to unlock the stack" do
      @stack.update!(lock_reason: 'Went out to eat some chips!')
      assert @stack.locked?

      patch :update, params: { id: @stack.to_param, stack: { lock_reason: '' } }
      @stack.reload
      refute @stack.locked?
      assert_instance_of AnonymousUser, @stack.lock_author
    end

    test "#update allows to archive the stack" do
      refute @stack.archived?
      refute @stack.locked?

      patch :update, params: { id: @stack.to_param, stack: { archived: "true" } }
      @stack.reload
      assert @stack.archived?
      assert @stack.locked?
      assert_equal shipit_users(:walrus), @stack.lock_author
      assert_equal "Archived", @stack.lock_reason
    end

    test "#update allows to dearchive the stack" do
      @stack.archive!(shipit_users(:walrus))
      assert @stack.locked?
      assert @stack.archived?

      patch :update, params: { id: @stack.to_param, stack: { archived: "false" } }
      @stack.reload
      refute @stack.archived?
      refute @stack.locked?
      assert_nil @stack.locked_since
      assert_nil @stack.lock_reason
      assert_instance_of AnonymousUser, @stack.lock_author
    end

    test "#refresh queues a RefreshStatusesJob and a GithubSyncJob" do
      request.env['HTTP_REFERER'] = stack_settings_path(@stack)

      assert_enqueued_with(job: RefreshStatusesJob, args: [stack_id: @stack.id]) do
        assert_enqueued_with(job: RefreshCheckRunsJob, args: [stack_id: @stack.id]) do
          assert_enqueued_with(job: GithubSyncJob, args: [stack_id: @stack.id]) do
            post :refresh, params: { id: @stack.to_param }
          end
        end
      end

      assert_redirected_to stack_settings_path(@stack)
    end

    test "#clear_git_cache queues a ClearGitCacheJob" do
      assert_enqueued_with(job: ClearGitCacheJob, args: [@stack]) do
        post :clear_git_cache, params: { id: @stack.to_param }
      end
      assert_redirected_to stack_settings_path(@stack)
    end

    test "#clear_git_cache displays a flash message" do
      post :clear_git_cache, params: { id: @stack.to_param }
      assert_equal 'Git Cache clearing scheduled', flash[:success]
    end

    test "#update redirects to return_to parameter" do
      patch :update, params: { id: @stack.to_param, stack: { ignore_ci: false }, return_to: stack_path(@stack) }
      assert_redirected_to stack_path(@stack)
    end

    test "#lookup redirects to the canonical URL" do
      get :lookup, params: { id: @stack.id }
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
