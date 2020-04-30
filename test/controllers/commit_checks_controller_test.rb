# frozen_string_literal: true
require 'test_helper'

module Shipit
  class CommitChecksControllerTest < ActionController::TestCase
    setup do
      @commit = shipit_commits(:fifth)
      @checks = @commit.checks
      @stack = @commit.stack
      @checks.write('foobar')
      @checks.status = 'running'
      session[:user_id] = shipit_users(:walrus).id
    end

    test ":tail is success" do
      get :tail, params: { stack_id: @stack.to_param, sha: @commit.sha }
      assert_response :success
      assert_json 'output', 'foobar'
      assert_json 'url', stack_tail_commit_checks_path(@stack, sha: @commit.sha, since: 6)
      assert_json 'status', 'running'
    end

    test ":tail doesn't provide another url if the task is finished" do
      @checks.status = 'success'
      get :tail, params: { stack_id: @stack.to_param, sha: @commit.sha }
      assert_response :success
      assert_json 'url', nil
    end

    test ":tail returns only the output after the provided offset" do
      @checks.status = 'success'
      get :tail, params: { stack_id: @stack.to_param, sha: @commit.sha, since: 5 }
      assert_response :success
      assert_json 'output', 'r'
    end
  end
end
