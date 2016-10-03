require 'test_helper'

module Shipit
  module Api
    class CommitsControllerTest < ActionController::TestCase
      setup do
        @stack = shipit_stacks(:shipit)
        authenticate!
      end

      test "#index returns a list of commits" do
        commit = @stack.commits.last

        get :index, params: {stack_id: @stack.to_param}
        assert_response :ok
        assert_json '0.sha', commit.sha
      end
    end
  end
end
