# frozen_string_literal: true
require 'test_helper'

module Shipit
  class WebhooksControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      GithubHook.any_instance.stubs(:verify_signature).returns(true)
    end

    test "create github repository which is not yet present in the datastore" do
      request.headers['X-Github-Event'] = 'push'
      unknown_repo_payload = JSON.parse(payload(:push_master))
      unknown_repo_payload["repository"]["full_name"] = "owner/unknown-repository"
      unknown_repo_payload = unknown_repo_payload.to_json

      assert_nothing_raised do
        post :create, body: unknown_repo_payload, as: :json
      end
    end

    test ":push with the target branch queues a GithubSyncJob" do
      request.headers['X-Github-Event'] = 'push'

      body = JSON.parse(payload(:push_master)).to_json
      assert_enqueued_with(job: GithubSyncJob, args: [stack_id: @stack.id]) do
        post :create, body: body, as: :json
      end
    end

    test ":push does not enqueue a job if not the target branch" do
      request.headers['X-Github-Event'] = 'push'
      params = JSON.parse(payload(:push_not_master)).to_json
      assert_no_enqueued_jobs do
        post :create, body: params, as: :json
      end
    end

    test ":state create a Status for the specific commit" do
      request.headers['X-Github-Event'] = 'status'

      commit = shipit_commits(:first)

      body = JSON.parse(payload(:status_master)).merge(repository_params).to_json
      assert_difference 'commit.statuses.count', 1 do
        post :create, body: body, as: :json
      end

      status = commit.statuses.last
      status_payload = JSON.parse(payload(:status_master))
      assert_equal status_payload['target_url'], status.target_url
      assert_equal status_payload['state'], status.state
      assert_equal status_payload['description'], status.description
      assert_equal status_payload['context'], status.context
      assert_equal status_payload['created_at'], status.created_at.iso8601
    end

    test ":state with a unexisting commit respond with 200 OK" do
      request.headers['X-Github-Event'] = 'status'
      params = { 'sha' => 'notarealcommit', 'state' => 'pending', 'branches' => [{ 'name' => 'master' }] }.merge(repository_params).to_json
      post :create, body: params, as: :json
      assert_response :ok
    end

    test ":state in an untracked branche bails out" do
      request.headers['X-Github-Event'] = 'status'
      params = { 'sha' => 'notarealcommit', 'state' => 'pending', 'branches' => [] }.merge(repository_params).to_json
      post :create, body: params, as: :json
      assert_response :ok
    end

    test ":check_suite with the target branch queues a RefreshCheckRunsJob" do
      request.headers['X-Github-Event'] = 'check_suite'

      body = JSON.parse(payload(:check_suite_master)).to_json
      assert_enqueued_with(job: RefreshCheckRunsJob) do
        post :create, body: body, as: :json
        assert_response :ok
      end
    end

    test "returns head :ok if request is ping" do
      @request.headers['X-Github-Event'] = 'ping'

      assert_no_enqueued_jobs do
        post :create, body: { zen: 'Git is beautiful' }.to_json, as: :json
        assert_response :ok
      end
    end

    test "verifies webhook signature" do
      commit = shipit_commits(:first)

      payload = { "sha" => commit.sha, "state" => "pending", "target_url" => "https://ci.example.com/1000/output" }.merge(repository_params).to_json
      signature = 'sha1=4848deb1c9642cd938e8caa578d201ca359a8249'

      @request.headers['X-Github-Event'] = 'push'
      @request.headers['X-Hub-Signature'] = signature

      Shipit.github(organization: 'shopify').expects(:verify_webhook_signature).with(signature, payload).returns(false)

      post :create, body: payload, as: :json
      assert_response :unprocessable_entity
    end

    test ":membership creates the mentioned team on the fly" do
      @request.headers['X-Github-Event'] = 'membership'
      assert_difference -> { Team.count }, 1 do
        post :create, as: :json, body: membership_params.merge(team: {
          id: 48,
          name: 'Ouiche Cooks',
          slug: 'ouiche-cooks',
          url: 'https://example.com',
        }).to_json
        assert_response :ok
      end
    end

    test ":membership creates the mentioned user on the fly" do
      @request.headers['X-Github-Event'] = 'membership'
      Shipit.github.api.expects(:user).with('george').returns(george)
      assert_difference -> { User.count }, 1 do
        post :create, body: membership_params.merge(member: { login: 'george' }).to_json, as: :json
        assert_response :ok
      end
    end

    test ":membership can delete an user membership" do
      @request.headers['X-Github-Event'] = 'membership'
      assert_difference -> { Membership.count }, -1 do
        post :create, body: membership_params.merge(action: 'removed').to_json, as: :json
        assert_response :ok
      end
    end

    test ":membership can append an user membership" do
      @request.headers['X-Github-Event'] = 'membership'
      assert_difference -> { Membership.count }, 1 do
        post :create, body: membership_params.merge(member: { login: 'bob' }).to_json, as: :json
        assert_response :ok
      end
    end

    test ":membership can append an user twice" do
      @request.headers['X-Github-Event'] = 'membership'
      assert_no_difference -> { Membership.count } do
        post :create, body: membership_params.to_json, as: :json
        assert_response :ok
      end
    end

    test ":membership can delete an user twice" do
      @request.headers['X-Github-Event'] = 'membership'
      assert_no_difference -> { Membership.count } do
        post :create, body: membership_params.merge(action: 'removed', member: { login: 'bob' }).to_json, as: :json
        assert_response :ok
      end
    end

    test "other events trigger custom handlers" do
      event = 'pull_request'
      mock_handler = mock
      mock_handler.expects(:call).with(pull_request_params.deep_stringify_keys).once
      Shipit::Webhooks.handlers["pull_request"] = [mock_handler]

      @request.headers['X-Github-Event'] = event
      post :create, body: pull_request_params.to_json, as: :json
      assert_response :ok
    end

    test "events with no handler are dropped" do
      event = 'not_a_real_event'

      @request.headers['X-Github-Event'] = event
      post :create, body: pull_request_params.to_json, as: :json
      assert_response 204
    end

    private

    def pull_request_params
      { action: 'opened', number: 2, pull_request: 'foobar' }.merge(repository_params)
    end

    def membership_params
      { action: 'added', team: team_params, organization: { login: 'shopify' }, member: { login: 'walrus' } }.merge(repository_params)
    end

    def team_params
      { id: shipit_teams(:shopify_developers).id, slug: 'developers', name: 'Developers', url: 'http://example.com' }
    end

    def repository_params
      { repository: { owner: { login: 'shopify' } } }
    end

    def george
      stub(
        id: 42,
        name: 'George Abitbol',
        login: 'george',
        email: 'george@cyclim.se',
        avatar_url: 'https://avatars.githubusercontent.com/u/42?v=3',
        url: 'https://api.github.com/user/george',
      )
    end
  end
end
