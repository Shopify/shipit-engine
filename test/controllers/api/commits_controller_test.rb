require 'test_helper'

module Shipit
  module Api
    class CommitsControllerTest < ActionController::TestCase
      setup do
        @stack = shipit_stacks(:shipit)
        authenticate!
      end

      test "#index returns a list of commits" do
        commit = @stack.commits.reachable.last

        get :index, params: {stack_id: @stack.to_param}
        assert_response :ok
        assert_json '0.sha', commit.sha
      end

      test "#index with undeployed=1 returns a list of undeployed commits" do
        commits = @stack.undeployed_commits.pluck(:sha)

        get :index, params: {stack_id: @stack.to_param, undeployed: 1}
        assert_response :ok
        JSON.parse(response.body).each do |commit|
          assert commits.include?(commit.fetch("sha"))
        end
      end
    end
  end
end
