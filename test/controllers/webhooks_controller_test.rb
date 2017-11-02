require 'test_helper'

module Shipit
  class WebhooksControllerTest < ActionController::TestCase
    setup do
      @stack = shipit_stacks(:shipit)
      GithubHook.any_instance.stubs(:verify_signature).returns(true)
    end

    test ":push with the target branch queues a GithubSyncJob" do
      request.headers['X-Github-Event'] = 'push'
      params = payload(:push_master)

      assert_enqueued_with(job: GithubSyncJob, args: [stack_id: @stack.id]) do
        post :push, params: {stack_id: @stack.id}.merge(params)
      end
    end

    test ":push does not enqueue a job if not the target branch" do
      request.headers['X-Github-Event'] = 'push'
      params = payload(:push_not_master)
      assert_no_enqueued_jobs do
        post :push, params: {stack_id: @stack.id}.merge(params)
      end
    end

    test ":state create a Status for the specific commit" do
      request.headers['X-Github-Event'] = 'status'

      status_payload = payload(:status_master)
      commit = shipit_commits(:first)

      assert_difference 'commit.statuses.count', 1 do
        post :state, params: {stack_id: @stack.id}.merge(status_payload)
      end

      status = commit.statuses.last
      assert_equal status_payload['target_url'], status.target_url
      assert_equal status_payload['state'], status.state
      assert_equal status_payload['description'], status.description
      assert_equal status_payload['context'], status.context
      assert_equal status_payload['created_at'], status.created_at.iso8601
    end

    test ":state with a unexisting commit respond with 200 OK" do
      request.headers['X-Github-Event'] = 'status'
      params = {'sha' => 'notarealcommit', 'state' => 'pending', 'branches' => [{'name' => 'master'}]}
      post :state, params: {stack_id: @stack.id}.merge(params)
      assert_response :ok
    end

    test ":state in an untracked branche bails out" do
      request.headers['X-Github-Event'] = 'status'
      params = {'sha' => 'notarealcommit', 'state' => 'pending', 'branches' => []}
      post :state, params: {stack_id: @stack.id}.merge(params)
      assert_response :ok
    end

    test ":push returns head :ok if request is ping" do
      @request.headers['X-Github-Event'] = 'ping'

      assert_no_enqueued_jobs do
        post :state, params: {stack_id: @stack.id, zen: 'Git is beautiful'}
        assert_response :ok
      end
    end

    test ":state returns head :ok if request is ping" do
      @request.headers['X-Github-Event'] = 'ping'

      assert_no_enqueued_jobs do
        post :state, params: {stack_id: @stack.id}
        assert_response :ok
      end
    end

    test ":state verifies webhook signature" do
      commit = shipit_commits(:first)

      params = {"sha" => commit.sha, "state" => "pending", "target_url" => "https://ci.example.com/1000/output"}
      signature = 'sha1=4848deb1c9642cd938e8caa578d201ca359a8249'

      @request.headers['X-Github-Event'] = 'push'
      @request.headers['X-Hub-Signature'] = signature

      GithubHook.any_instance.expects(:verify_signature).with(signature, URI.encode_www_form(params)).returns(false)

      post :push, params: {stack_id: @stack.id}.merge(params)
      assert_response :unprocessable_entity
    end

    test ":push verifies webhook signature" do
      params = {"ref" => "refs/heads/master"}
      signature = 'sha1=ad1d939e9acd6bdc2415a2dd5951be0f2a796ce0'

      @request.headers['X-Github-Event'] = 'push'
      @request.headers['X-Hub-Signature'] = signature

      GithubHook.any_instance.expects(:verify_signature).with(signature, URI.encode_www_form(params)).returns(false)

      post :push, params: {stack_id: @stack.id}.merge(params)
      assert_response :unprocessable_entity
    end

    test ":membership creates the mentioned team on the fly" do
      assert_difference -> { Team.count }, 1 do
        post :membership, params: membership_params.merge(team: {
          id: 48,
          name: 'Ouiche Cooks',
          slug: 'ouiche-cooks',
          url: 'https://example.com',
        })
        assert_response :ok
      end
    end

    test ":membership creates the mentioned user on the fly" do
      Shipit.github_api.expects(:user).with('george').returns(george)
      assert_difference -> { User.count }, 1 do
        post :membership, params: membership_params.merge(member: {login: 'george'})
        assert_response :ok
      end
    end

    test ":membership can delete an user membership" do
      assert_difference -> { Membership.count }, -1 do
        post :membership, params: membership_params.merge(_action: 'removed')
        assert_response :ok
      end
    end

    test ":membership can append an user membership" do
      assert_difference -> { Membership.count }, 1 do
        post :membership, params: membership_params.merge(member: {login: 'bob'})
        assert_response :ok
      end
    end

    test ":membership can append an user twice" do
      assert_no_difference -> { Membership.count } do
        post :membership, params: membership_params
        assert_response :ok
      end
    end

    test ":membership can delete an user twice" do
      assert_no_difference -> { Membership.count } do
        post :membership, params: membership_params.merge(_action: 'removed', member: {login: 'bob'})
        assert_response :ok
      end
    end

    private

    def membership_params
      {_action: 'added', team: team_params, organization: {login: 'shopify'}, member: {login: 'walrus'}}
    end

    def team_params
      {id: shipit_teams(:shopify_developers).id, slug: 'developers', name: 'Developers', url: 'http://example.com'}
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
