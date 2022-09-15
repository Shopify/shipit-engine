# frozen_string_literal: true
require 'test_helper'

module Shipit
  module Api
    class BaseControllerTest < ApiControllerTestCase
      test "authentication is required" do
        get :index
        assert_response :unauthorized
        assert_equal({ message: 'Bad credentials' }.to_json, response.body)
      end

      test "with proper credentials the request is processed" do
        authenticate!
        assert_response :ok
      end

      test "#index respond with a list of endpoints" do
        authenticate!
        get :index, format: :json
        assert_equal({ stacks_url: api_stacks_url }.to_json, response.body)
      end
    end
  end
end
