# frozen_string_literal: true

require 'test_helper'

module Shipit
  class ApiClientsControllerTest < ActionController::TestCase
    setup do
      @routes = Shipit::Engine.routes
      @api_client = shipit_api_clients(:here_come_the_walrus)
      session[:user_id] = shipit_users(:walrus).id
    end

    test "GitHub authentication is mandatory" do
      session[:user_id] = nil
      get :index
      assert_redirected_to '/github/auth/github?origin=http%3A%2F%2Ftest.host%2Fapi_clients'
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

    test "#index is successful with a valid user" do
      get :index
      assert_response :ok
    end

    test "#new is success" do
      get :new
      assert_response :ok
    end

    test "#create creates a new api_client" do
      assert_difference "ApiClient.count", +1 do
        post :create, params: {
          api_client: {
            name: 'walrus_app',
            permissions: [
              'read:stack',
              'lock:stack',
            ],
          },
        }
      end

      assert_redirected_to api_client_path(ApiClient.last)
    end

    test "#create attaches the current user to the created api client" do
      post :create, params: {
        api_client: {
          name: 'walrus_app',
          permissions: [
            'read:stack',
            'lock:stack',
          ],
        },
      }

      assert_equal shipit_users(:walrus).id, ApiClient.last.creator.id
    end

    test "#create when not valid renders new" do
      assert_no_difference "Stack.count" do
        post :create, params: { api_client: { name: 'walrus_app', permissions: ['invalid'] } }
      end

      assert flash[:warning]
      assert_response :success
    end

    test "#show is success" do
      get :show, params: { id: @api_client.id }
      assert_response :ok
    end

    test "#update updates an existing api_client" do
      new_permissions = [
        'read:stack',
        'lock:stack',
      ]

      assert_difference "ApiClient.count", 0 do
        patch :update, params: {
          id: @api_client.id,
          api_client: {
            permissions: new_permissions,
          },
        }
      end
      @api_client.reload

      assert_redirected_to api_client_path(@api_client)
      assert_equal new_permissions, @api_client.permissions
    end
  end
end
