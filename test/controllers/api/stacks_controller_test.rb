# frozen_string_literal: true
require 'test_helper'

module Shipit
  module Api
    class StacksControllerTest < ApiControllerTestCase
      setup do
        authenticate!
        @stack = shipit_stacks(:shipit)
      end

      test "#create fails with insufficient permissions" do
        @client.permissions.delete('write:stack')
        @client.save!

        assert_no_difference 'Stack.count' do
          post :create, params: { repo_name: 'rails', repo_owner: 'rails', environment: 'staging', branch: 'staging' }
        end

        assert_response :forbidden
        assert_json 'message', 'This operation requires the `write:stack` permission'
      end

      test "#create fails with invalid stack" do
        assert_no_difference "Stack.count" do
          post :create, params: { repo_owner: 'some', repo_name: 'owner/path', branch: 'main' }
        end
        assert_response :unprocessable_entity
        assert_json 'errors', 'repository' => ['is invalid']
      end

      test "#create creates a stack and renders it back" do
        assert_difference -> { Stack.count } do
          post :create, params: { repo_name: 'rails', repo_owner: 'rails', environment: 'staging', branch: 'staging' }
        end

        assert_response :ok
        assert_json 'id', Stack.last.id
      end

      test "#create fails to create stack if it already exists" do
        repository = shipit_repositories(:rails)
        existing_stack = Stack.create!(
          repository: repository,
          environment: 'staging',
          branch: 'staging',
        )

        assert_no_difference -> { Stack.count } do
          post :create,
            params: {
              repo_name: existing_stack.repo_name,
              repo_owner: existing_stack.repo_owner,
              environment: existing_stack.environment,
              branch: existing_stack.branch,
            }
        end

        assert_response :unprocessable_entity
        assert_json 'errors', 'repository' => [
          'cannot be used more than once with this environment. Check archived stacks.',
        ]
      end

      test "#update updates a stack and renders it back" do
        assert_equal true, @stack.merge_queue_enabled
        assert_equal false, @stack.ignore_ci
        assert_equal false, @stack.continuous_deployment

        patch :update, params: {
          id: @stack.to_param,
          merge_queue_enabled: false,
          ignore_ci: true,
          continuous_deployment: true,
        }

        assert_response :ok
        @stack.reload

        assert_equal false, @stack.merge_queue_enabled
        assert_equal true, @stack.ignore_ci
        assert_equal true, @stack.continuous_deployment
      end

      test "#update allows changing the branch name" do
        assert_equal 'master', @stack.branch

        patch :update, params: {
          id: @stack.to_param,
          branch: 'test',
        }

        assert_response :ok
        @stack.reload

        assert_equal 'test', @stack.branch
      end

      test "#update updates the stack when nil deploy_url" do
        @stack.update(deploy_url: nil)
        @stack.update(continuous_deployment: true)
        assert_nil @stack.deploy_url
        assert @stack.continuous_deployment

        patch :update, params: {
          id: @stack.to_param,
          continuous_deployment: false,
        }

        assert_response :ok
        @stack.reload

        assert_nil @stack.deploy_url
        refute @stack.continuous_deployment
      end

      test "#update does not perform archive when key is not provided" do
        refute_predicate @stack, :archived?
        refute_predicate @stack, :locked?

        patch :update, params: { id: @stack.to_param }

        @stack.reload
        refute_predicate @stack, :archived?
        refute_predicate @stack, :locked?
      end

      test "#update does not perform unarchive when key is not provided" do
        @stack.archive!(shipit_users(:walrus))
        assert_predicate @stack, :locked?
        assert_predicate @stack, :archived?

        patch :update, params: { id: @stack.to_param }

        @stack.reload
        assert_predicate @stack, :locked?
        assert_predicate @stack, :archived?
      end

      test "#update allows to archive the stack" do
        refute_predicate @stack, :archived?
        refute_predicate @stack, :locked?

        patch :update, params: { id: @stack.to_param, archived: true }

        @stack.reload
        assert_predicate @stack, :locked?
        assert_predicate @stack, :archived?
        assert_instance_of AnonymousUser, @stack.lock_author
        assert_equal "Archived", @stack.lock_reason
      end

      test "#update allows to unarchive the stack" do
        @stack.archive!(shipit_users(:walrus))
        assert_predicate @stack, :locked?
        assert_predicate @stack, :archived?

        patch :update, params: { id: @stack.to_param, archived: false }

        @stack.reload
        refute_predicate @stack, :archived?
        refute_predicate @stack, :locked?
        assert_nil @stack.locked_since
        assert_nil @stack.lock_reason
        assert_instance_of AnonymousUser, @stack.lock_author
      end

      test "#index returns a list of stacks" do
        stack = Stack.last
        get :index
        assert_response :ok
        assert_json '0.id', stack.id
        assert_json do |stacks|
          assert_equal Stack.count, stacks.size
        end
      end

      test "#index returns a list of stacks filtered by repo if name and owner given" do
        repo = shipit_repositories(:shipit)
        get :index, params: { repo_owner: repo.owner, repo_name: repo.name }
        assert_response :ok
        assert_json do |stacks|
          assert_equal stacks.size, repo.stacks.size
        end
      end

      test "#index returns a list of stacks filtered by repo and api client" do
        authenticate!(:here_come_the_walrus)

        repo = shipit_repositories(:soc)

        get :index, params: { repo_owner: repo.owner, repo_name: repo.name }
        assert_response :ok
        assert_json do |stacks|
          assert_equal 0, stacks.size
        end
      end

      test "#index is paginable" do
        get :index, params: { page_size: 1 }
        assert_json do |list|
          assert_instance_of Array, list
          assert_equal 1, list.size

          stack_id = list.last['id']
          assert_link 'next', api_stacks_url(since: stack_id, page_size: 1)
          assert_link 'first', api_stacks_url(page_size: 1)
        end
      end

      test "the `next` link is not provided when the last page is reached" do
        get :index, params: { page_size: Stack.count }
        assert_no_link 'next'
      end

      test "an api client scoped to a stack will only see that one stack" do
        authenticate!(:here_come_the_walrus)
        get :index
        assert_json do |stacks|
          assert_equal 1, stacks.size
        end
      end

      test "a request with insufficient permissions will render a 403" do
        @client.update!(permissions: [])
        get :index
        assert_response :forbidden
        assert_json 'message', 'This operation requires the `read:stack` permission'
      end

      test "#show renders the stack" do
        get :show, params: { id: @stack.to_param }
        assert_response :ok
        assert_json 'id', @stack.id
      end

      test "#show returns last_deployed_at column for stack" do
        get :show, params: { id: @stack.to_param }
        assert_response :ok
        assert_json 'last_deployed_at', @stack.last_deployed_at
      end

      test "#destroy schedules stack deletion job" do
        assert_enqueued_with(job: DestroyStackJob) do
          delete :destroy, params: { id: @stack.to_param }
        end
        assert_response :accepted
      end

      test "#destroy fails with insufficient permissions" do
        @client.permissions.delete('write:stack')
        @client.save!

        assert_no_difference 'Stack.count' do
          delete :destroy, params: { id: @stack.to_param }
        end

        assert_response :forbidden
        assert_json 'message', 'This operation requires the `write:stack` permission'
      end

      test "#refresh queues a GithubSyncJob" do
        assert_enqueued_with(job: GithubSyncJob, args: [stack_id: @stack.id]) do
          post :refresh, params: { id: @stack.to_param }
        end
        assert_response :accepted
      end

      test "#refresh queues a RefreshStatusesJob and RefreshCheckRunsJob" do
        assert_enqueued_with(job: RefreshStatusesJob, args: [stack_id: @stack.id]) do
          assert_enqueued_with(job: RefreshCheckRunsJob, args: [stack_id: @stack.id]) do
            post :refresh, params: { id: @stack.to_param }
          end
        end
        assert_response :accepted
      end
    end
  end
end
