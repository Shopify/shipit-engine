require 'test_helper'

class WebhooksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
  end

  test ":push with the target branch queues a job" do
    Resque.expects(:enqueue).with(GithubSyncJob, stack_id: @stack.id)
    Resque.expects(:enqueue).with(GitMirrorUpdateJob, stack_id: @stack.id)

    Webhook.any_instance.expects(:verify_signature).returns(true)

    request.headers['X-Github-Event'] = 'push'
    params = payload(:push_master)
    post :push, { stack_id: @stack.id }.merge(params)
  end

  test ":push does not enqueue a job if not the target branch" do
    Resque.expects(:enqueue).never
    Webhook.any_instance.expects(:verify_signature).returns(true)

    request.headers['X-Github-Event'] = 'push'
    params = payload(:push_not_master)
    post :push, { stack_id: @stack.id }.merge(params)
  end

  test ":state updates the commit with the payload state" do
    Webhook.any_instance.expects(:verify_signature).returns(true)
    commit = commits(:first)

    request.headers['X-Github-Event'] = 'status'
    params = {"sha" => commit.sha, "state" => "pending", "target_url" => "https://ci.example.com/1000/output"}
    post :state, { stack_id: @stack.id }.merge(params)

    commit.reload
    assert_equal 'pending', commit.state
    assert_equal "https://ci.example.com/1000/output", commit.target_url
  end

  test ":state with a unexisting commit trows ActiveRecord::RecordNotFound" do
    Webhook.any_instance.expects(:verify_signature).returns(true)

    request.headers['X-Github-Event'] = 'status'
    params = {"sha" => "notarealcommit", "state" => "pending"}
    assert_raises ActiveRecord::RecordNotFound do
      post :state, { stack_id: @stack.id }.merge(params)
    end
  end

  test ":push returns head :ok if request is ping" do
    @request.headers['X-Github-Event'] = 'ping'

    Resque.expects(:enqueue).never
    post :state, { stack_id: @stack.id, zen: "Git is beautiful" }
    assert_response :ok
  end

  test ":state returns head :ok if request is ping" do
    @request.headers['X-Github-Event'] = 'ping'

    post :state, { stack_id: @stack.id }
    Resque.expects(:enqueue).never
    assert_response :ok
  end

  test ":state verifies webhook signature" do
    commit = commits(:first)

    params = {"sha" => commit.sha, "state" => "pending", "target_url" => "https://ci.example.com/1000/output"}
    signature = 'sha1=4848deb1c9642cd938e8caa578d201ca359a8249'

    @request.headers['X-Github-Event'] = 'push'
    @request.headers['X-Hub-Signature'] = signature

    Webhook.any_instance.expects(:verify_signature).with(signature, URI.encode_www_form(params)).returns(false)

    post :push, { stack_id: @stack.id }.merge(params)
    assert_response :unprocessable_entity
  end

  test ":push verifies webhook signature" do
    params = {"ref" => "refs/heads/master"}
    signature = 'sha1=ad1d939e9acd6bdc2415a2dd5951be0f2a796ce0'

    @request.headers['X-Github-Event'] = 'push'
    @request.headers['X-Hub-Signature'] = signature

    Webhook.any_instance.expects(:verify_signature).with(signature, URI.encode_www_form(params)).returns(false)

    post :push, { stack_id: @stack.id }.merge(params)
    assert_response :unprocessable_entity
  end
end
