require 'test_helper'

module Shipit
  module Api
    class StacksControllerTest < ActionController::TestCase
      setup do
        authenticate!
        @stack = shipit_stacks(:shipit)
      end

      test "#create fails with insufficient permissions" do
        @client.permissions.delete('write:stack')
        @client.save!

        assert_no_difference 'Stack.count' do
          post :create, repo_name: 'rails', repo_owner: 'rails', environment: 'staging', branch: 'staging'
        end

        assert_response :forbidden
        assert_json 'message', 'This operation requires the `write:stack` permission'
      end

      test "#create fails with invalid stack" do
        assert_no_difference "Stack.count" do
          post :create, repo_owner: 'some', repo_name: 'owner/path'
        end
        assert_response :unprocessable_entity
        assert_json 'errors', 'repo_name' => ['is invalid']
      end

      test "#create creates a stack and renders it back" do
        assert_difference -> { Stack.count } do
          post :create, repo_name: 'rails', repo_owner: 'rails', environment: 'staging', branch: 'staging'
        end

        assert_response :ok
        assert_json 'id', Stack.last.id
      end

      test "#create fails to create stack if it already exists" do
        Stack.create!(
          repo_name: 'rails',
          repo_owner: 'rails',
          environment: 'staging',
          branch: 'staging',
        )

        assert_no_difference -> { Stack.count } do
          post :create, repo_name: 'rails', repo_owner: 'rails', environment: 'staging', branch: 'staging'
        end

        assert_response :unprocessable_entity
        assert_json 'errors', 'repo_name' => ['cannot be used more than once with this environment']
      end

      test "#index returns a list of stacks" do
        stack = Stack.last

        get :index
        assert_response :ok
        assert_json '0.id', stack.id
        assert_json do |stacks|
          assert_equal 3, stacks.size
        end
      end

      test "#index is paginable" do
        get :index, page_size: 1
        assert_json do |list|
          assert_instance_of Array, list
          assert_equal 1, list.size

          stack_id = list.last['id']
          assert_link 'next', api_stacks_url(since: stack_id, page_size: 1)
          assert_link 'first', api_stacks_url(page_size: 1)
        end
      end

      test "the `next` link is not provided when the last page is reached" do
        get :index, page_size: Stack.count
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
        get :show, id: @stack.to_param
        assert_response :ok
        assert_json 'id', @stack.id
      end
    end
  end
end
