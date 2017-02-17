require 'uri'
require 'test_helper'

module Shipit
  class CcmenuUrlControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      @user = shipit_users(:walrus)
      session[:user_id] = @user.id
    end

    test ":fetch returns ok with json" do
      get :fetch, params: {stack_id: @stack.to_param}
      assert_response :ok
      data = JSON.parse(response.body)
      assert_includes data, 'ccmenu_url'
    end

    test ":fetch creates a read only api client" do
      assert_difference 'ApiClient.count' do
        get :fetch, params: {stack_id: @stack.to_param}
      end
    end

    test ":fetch url includes api token as username" do
      get :fetch, params: {stack_id: @stack.to_param}
      data = JSON.parse(response.body)
      client = ApiClient.last
      assert_equal client.authentication_token, URI(data['ccmenu_url']).user
    end
  end
end
