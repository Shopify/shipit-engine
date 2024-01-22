# frozen_string_literal: true

require 'test_helper'

module Shipit
  class MergeStatusControllerTest < ActionController::TestCase
    setup do
      request.env['HTTPS'] = 'on'
      @request.host = URI(Shipit.host).host
      session[:user_id] = shipit_users(:walrus).id
    end

    test "GET show" do
      get :show, params: { referrer: 'https://github.com/Shopify/shipit-engine/pull/42', branch: 'master' }
      assert_response :ok
      assert_includes response.body, 'Ready to ship!'
    end

    test "GET show when there is no matching stacks" do
      get :show, params: { referrer: 'https://github.com/Shopify/unknown-repo/pull/42', branch: 'master' }
      assert_response :ok
      assert_predicate response.body, :blank?
    end

    test "GET anonymous show returns a login message" do
      session.delete(:user_id)
      get :show, params: { referrer: 'https://github.com/Shopify/shipit-engine/pull/42', branch: 'master' }
      assert_response :ok
      assert_includes response.body.downcase, 'please log in'
    end

    test "GET anonymous show when there is no matching stack is blank" do
      session.delete(:user_id)
      get :show, params: { referrer: 'https://github.com/Shopify/unknown-repo/pull/42', branch: 'master' }
      assert_response :ok
      assert_predicate response.body, :blank?
    end

    test "GET show prefers stacks with merge_queue_enabled" do
      existing = shipit_stacks(:shipit)
      Shipit::Stack.where(
        repository: existing.repository,
      ).update_all(merge_queue_enabled: false)

      Shipit::Stack.create(
        repository: existing.repository,
        environment: 'foo',
        branch: existing.branch,
        merge_queue_enabled: true,
      )

      get :show, params: { referrer: 'https://github.com/Shopify/shipit-engine/pull/42', branch: 'master' }
      assert_response :ok
      assert_includes response.body, 'shipit-engine/foo'
    end

    test "GET show prefers locked stacks above all else" do
      existing = shipit_stacks(:shipit)
      Shipit::Stack.where(
        repository: existing.repository,
      ).update_all(lock_reason: 'testing', merge_queue_enabled: false, locked_since: Time.now.utc)

      # Shipit would otherwise prefer this, because it has the merge queue enabled
      Shipit::Stack.create(
        repository: existing.repository,
        environment: 'foo',
        branch: existing.branch,
        merge_queue_enabled: true,
      )

      get :show, params: { referrer: 'https://github.com/Shopify/shipit-engine/pull/42', branch: 'master' }
      assert_response :ok
      assert_includes response.body, 'locked'
    end
  end
end
