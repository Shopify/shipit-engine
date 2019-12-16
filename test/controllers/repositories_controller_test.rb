require 'test_helper'

module Shipit
  class RepositoriesControllerTest < ActionController::TestCase
    setup do
      @routes = Shipit::Engine.routes
      @repository = shipit_repositories(:shipit)
      session[:user_id] = shipit_users(:walrus).id
    end

    test "GitHub authentication is mandatory" do
      session[:user_id] = nil
      get :index
      assert_redirected_to '/github/auth/github?origin=http%3A%2F%2Ftest.host%2Frepositories'
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
      get :show, params: {id: @repository.to_param}
      assert_response :ok
    end

    test "#create creates a repository and redirects to it" do
      assert_difference "Repository.count" do
        post :create, params: {
               repository: {
                 name: 'valid',
                 owner: 'repository',
               },
             }
      end
      assert_redirected_to repository_path(Repository.last)
    end

    test "#create when not valid renders new" do
      assert_no_difference "Repository.count" do
        post :create, params: {
               repository: {
                 owner: 'some',
                 name: 'owner/path',
               },
             }
      end
      assert_response :success
    end

    test "#destroy enqueues a DestroyRepositoryJob" do
      assert_enqueued_with(job: DestroyRepositoryJob, args: [@repository]) do
        delete :destroy, params: {id: @repository.to_param}
      end

      assert_redirected_to repositories_path
    end

    test "#settings is success" do
      get :settings, params: {id: @repository.to_param}
      assert_response :success
    end
  end
end
