require 'test_helper'

class WebhooksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
  end

  test ":push with the target branch queues a job" do
    Resque.expects(:enqueue).with(GithubSyncJob, stack_id: @stack.id)
    Resque.expects(:enqueue).with(GitMirrorUpdateJob, stack_id: @stack.id)
    params = {"ref"=>"refs/heads/master", "after"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "before"=>"16c259864de2fc2da2e185c3088f4f33e5b09a3c", "created"=>false, "deleted"=>false, "forced"=>false, "compare"=>"https://github.com/byroot/junk/compare/16c259864de2...79d29e99cb83", "commits"=>[{"id"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "distinct"=>true, "message"=>"modif", "timestamp"=>"2014-02-28T10:27:42-08:00", "url"=>"https://github.com/byroot/junk/commit/79d29e99cb83e0ba16c9e30c502a60995e711e5f", "author"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "committer"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "added"=>nil, "removed"=>nil, "modified"=>["toto.txt"]}], "head_commit"=>{"id"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "distinct"=>true, "message"=>"modif", "timestamp"=>"2014-02-28T10:27:42-08:00", "url"=>"https://github.com/byroot/junk/commit/79d29e99cb83e0ba16c9e30c502a60995e711e5f", "author"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "committer"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "added"=>nil, "removed"=>nil, "modified"=>["toto.txt"]}, "repository"=>{"id"=>17266426, "name"=>"junk", "url"=>"https://github.com/byroot/junk", "description"=>"Pure test repo, look elsewhere please.", "watchers"=>0, "stargazers"=>0, "forks"=>0, "fork"=>false, "size"=>0, "owner"=>{"name"=>"byroot", "email"=>"jean.boussier@gmail.com"}, "private"=>false, "open_issues"=>0, "has_issues"=>true, "has_downloads"=>true, "has_wiki"=>true, "created_at"=>1393538266, "pushed_at"=>1393612064, "master_branch"=>"master"}, "pusher"=>{"name"=>"gmalette", "email"=>"gmalette@gmail.com"}, "webhook"=>{}}
    post :push, { stack_id: @stack.id }.merge(params)
  end

  test ":push does not enqueue a job if not the target branch" do
    Resque.expects(:enqueue).never
    params = {"ref"=>"refs/heads/not-master", "after"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "before"=>"16c259864de2fc2da2e185c3088f4f33e5b09a3c", "created"=>false, "deleted"=>false, "forced"=>false, "compare"=>"https://github.com/byroot/junk/compare/16c259864de2...79d29e99cb83", "commits"=>[{"id"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "distinct"=>true, "message"=>"modif", "timestamp"=>"2014-02-28T10:27:42-08:00", "url"=>"https://github.com/byroot/junk/commit/79d29e99cb83e0ba16c9e30c502a60995e711e5f", "author"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "committer"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "added"=>nil, "removed"=>nil, "modified"=>["toto.txt"]}], "head_commit"=>{"id"=>"79d29e99cb83e0ba16c9e30c502a60995e711e5f", "distinct"=>true, "message"=>"modif", "timestamp"=>"2014-02-28T10:27:42-08:00", "url"=>"https://github.com/byroot/junk/commit/79d29e99cb83e0ba16c9e30c502a60995e711e5f", "author"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "committer"=>{"name"=>"Guillaume Malette", "email"=>"gmalette@gmail.com", "username"=>"gmalette"}, "added"=>nil, "removed"=>nil, "modified"=>["toto.txt"]}, "repository"=>{"id"=>17266426, "name"=>"junk", "url"=>"https://github.com/byroot/junk", "description"=>"Pure test repo, look elsewhere please.", "watchers"=>0, "stargazers"=>0, "forks"=>0, "fork"=>false, "size"=>0, "owner"=>{"name"=>"byroot", "email"=>"jean.boussier@gmail.com"}, "private"=>false, "open_issues"=>0, "has_issues"=>true, "has_downloads"=>true, "has_wiki"=>true, "created_at"=>1393538266, "pushed_at"=>1393612064, "master_branch"=>"master"}, "pusher"=>{"name"=>"gmalette", "email"=>"gmalette@gmail.com"}, "webhook"=>{}}
    post :push, { stack_id: @stack.id }.merge(params)
  end

  test ":state updates the commit with the payload state" do
    commit = commits(:first)
    params = {"sha" => commit.sha, "state" => "pending"}
    post :state, { stack_id: @stack.id }.merge(params)

    assert_equal 'pending', commit.reload.state
  end

  test ":state with a unexisting commit trows ActiveRecord::RecordNotFound" do
    params = {"sha" => "notarealcommit", "state" => "pending"}
    assert_raises ActiveRecord::RecordNotFound do
      post :state, { stack_id: @stack.id }.merge(params)
    end
  end

  test ":push returns head :ok if request is ping" do
    @request.env['HTTP_X_GITHUB_EVENT'] = 'ping'

    Resque.expects(:enqueue).never
    post :state, { stack_id: @stack.id, zen: "Git is beautiful" }
    assert_response :ok
  end

  test ":state returns head :ok if request is ping" do
    @request.env['HTTP_X_GITHUB_EVENT'] = 'ping'

    commit = commits(:first)
    post :state, { stack_id: @stack.id }
    Resque.expects(:enqueue).never
    assert_response :ok
  end
end
