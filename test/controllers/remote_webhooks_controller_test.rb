require 'test_helper'

class RemoteWebhooksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
  end

  test ":push with the target branch queues a job" do
    Resque.expects(:enqueue).with(GithubSyncJob, stack_id: @stack.id)
    Resque.expects(:enqueue).with(GitMirrorUpdateJob, stack_id: @stack.id)

    RemoteWebhook.any_instance.expects(:verify_signature).returns(true)

    request.headers['X-Github-Event'] = 'push'
    params = {"ref"=>"refs/heads/master", "after"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "before"=>"16c259864de2fc2da2e185c3088f4f33e5b09a3c", "created"=>false, "deleted"=>false, "forced"=>false, "compare"=>"https://github.com/byroot/junk/compare/16c259864de2...79d29e99cb83", "commits"=>[{"id"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "distinct"=>true, "message"=>"modif", "timestamp"=>"2014-02-28T10:27:42-08:00", "url"=>"https://github.com/byroot/junk/commit/79d29e99cb83e0ba16c9e30c502a60995e711e5f", "author"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "committer"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "added"=>nil, "removed"=>nil, "modified"=>["toto.txt"]}], "head_commit"=>{"id"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "distinct"=>true, "message"=>"modif", "timestamp"=>"2014-02-28T10:27:42-08:00", "url"=>"https://github.com/byroot/junk/commit/79d29e99cb83e0ba16c9e30c502a60995e711e5f", "author"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "committer"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "added"=>nil, "removed"=>nil, "modified"=>["toto.txt"]}, "repository"=>{"id"=>17266426, "name"=>"junk", "url"=>"https://github.com/byroot/junk", "description"=>"Pure test repo, look elsewhere please.", "watchers"=>0, "stargazers"=>0, "forks"=>0, "fork"=>false, "size"=>0, "owner"=>{"name"=>"byroot", "email"=>"jean.boussier@gmail.com"}, "private"=>false, "open_issues"=>0, "has_issues"=>true, "has_downloads"=>true, "has_wiki"=>true, "created_at"=>1393538266, "pushed_at"=>1393612064, "master_branch"=>"master"}, "pusher"=>{"name"=>"gmalette", "email"=>"gmalette@gmail.com"}, "webhook"=>{}}
    post :push, { stack_id: @stack.id }.merge(params)
  end

  test ":push does not enqueue a job if not the target branch" do
    Resque.expects(:enqueue).never
    RemoteWebhook.any_instance.expects(:verify_signature).returns(true)

    request.headers['X-Github-Event'] = 'push'
    params = {"ref"=>"refs/heads/not-master", "after"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "before"=>"16c259864de2fc2da2e185c3088f4f33e5b09a3c", "created"=>false, "deleted"=>false, "forced"=>false, "compare"=>"https://github.com/byroot/junk/compare/16c259864de2...79d29e99cb83", "commits"=>[{"id"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "distinct"=>true, "message"=>"modif", "timestamp"=>"2014-02-28T10:27:42-08:00", "url"=>"https://github.com/byroot/junk/commit/79d29e99cb83e0ba16c9e30c502a60995e711e5f", "author"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "committer"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "added"=>nil, "removed"=>nil, "modified"=>["toto.txt"]}], "head_commit"=>{"id"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "distinct"=>true, "message"=>"modif", "timestamp"=>"2014-02-28T10:27:42-08:00", "url"=>"https://github.com/byroot/junk/commit/79d29e99cb83e0ba16c9e30c502a60995e711e5f", "author"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "committer"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "added"=>nil, "removed"=>nil, "modified"=>["toto.txt"]}, "repository"=>{"id"=>17266426, "name"=>"junk", "url"=>"https://github.com/byroot/junk", "description"=>"Pure test repo, look elsewhere please.", "watchers"=>0, "stargazers"=>0, "forks"=>0, "fork"=>false, "size"=>0, "owner"=>{"name"=>"byroot", "email"=>"jean.boussier@gmail.com"}, "private"=>false, "open_issues"=>0, "has_issues"=>true, "has_downloads"=>true, "has_wiki"=>true, "created_at"=>1393538266, "pushed_at"=>1393612064, "master_branch"=>"master"}, "pusher"=>{"name"=>"gmalette", "email"=>"gmalette@gmail.com"}, "webhook"=>{}}
    post :push, { stack_id: @stack.id }.merge(params)
  end

  test ":state updates the commit with the payload state" do
    RemoteWebhook.any_instance.expects(:verify_signature).returns(true)
    commit = commits(:first)

    request.headers['X-Github-Event'] = 'status'
    params = {"sha" => commit.sha, "state" => "pending", "target_url" => "https://ci.example.com/1000/output"}
    post :state, { stack_id: @stack.id }.merge(params)

    commit.reload
    assert_equal 'pending', commit.state
    assert_equal "https://ci.example.com/1000/output", commit.target_url
  end

  test ":state with a unexisting commit trows ActiveRecord::RecordNotFound" do
    RemoteWebhook.any_instance.expects(:verify_signature).returns(true)

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

    commit = commits(:first)
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

    RemoteWebhook.any_instance.expects(:verify_signature).with(signature, URI.encode_www_form(params)).returns(false)

    post :state, { stack_id: @stack.id }.merge(params)
    assert_response :unprocessable_entity
  end

  test ":push verifies webhook signature" do
    params = {"ref"=>"refs/heads/master"}
    signature = 'sha1=ad1d939e9acd6bdc2415a2dd5951be0f2a796ce0'

    @request.headers['X-Github-Event'] = 'push'
    @request.headers['X-Hub-Signature'] = signature

    RemoteWebhook.any_instance.expects(:verify_signature).with(signature, URI.encode_www_form(params)).returns(false)

    post :push, { stack_id: @stack.id }.merge(params)
    assert_response :unprocessable_entity
  end
end
