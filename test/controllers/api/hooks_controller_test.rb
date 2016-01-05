require 'test_helper'

module Shipit
  module Api
    class HooksControllerTest < ActionController::TestCase
      setup do
        authenticate!
        @stack = shipit_stacks(:shipit)
      end

      test "#index without a stack_id returns the list of global hooks" do
        hook = Hook.global.first

        get :index
        assert_response :ok
        assert_json '0.id', hook.id
        assert_json '0.url', hook.url
        assert_json '0.content_type', hook.content_type
        assert_no_json '0.stack'
      end

      test "#index with a stack_id returns the list of scoped hooks" do
        hook = Hook.scoped_to(@stack).first

        get :index, stack_id: @stack.to_param
        assert_response :ok
        assert_json '0.id', hook.id
        assert_json '0.url', hook.url
        assert_json '0.content_type', hook.content_type
        assert_json '0.stack.id', @stack.id
      end

      test "#show returns the hooks" do
        hook = Hook.scoped_to(@stack).first

        get :show, stack_id: @stack.to_param, id: hook.id
        assert_response :ok

        assert_json 'id', hook.id
        assert_json 'url', hook.url
        assert_json 'content_type', hook.content_type
        assert_json 'stack.id', @stack.id
      end

      test "#create adds a new hook" do
        assert_difference -> { Hook.count }, 1 do
          post :create, url: 'https://example.com/hook', events: %w(deploy rollback)
        end
        assert_json 'url', 'https://example.com/hook'
        assert_json 'id', Hook.last.id
      end

      test "#create do not allow to set protected attributes" do
        post :create, url: 'https://example.com/hook', events: %w(deploy rollback), created_at: 2.months.ago.to_s(:db)
        Hook.last.created_at > 2.seconds.ago
      end

      test "#create returns validation errors" do
        post :create, url: '../etc/passwd', events: %w(deploy)
        assert_response :unprocessable_entity
        assert_json 'errors', 'url' => ['is not a valid URL']
      end

      test "#update changes an existing hook" do
        hook = Hook.global.first
        patch :update, id: hook.id, url: 'https://shipit.com/'
        assert_response :ok
        assert_json 'url', 'https://shipit.com/'
      end

      test "#destroy removes an existing hook" do
        hook = Hook.global.first
        delete :destroy, id: hook.id
        assert_response :no_content
      end
    end
  end
end
