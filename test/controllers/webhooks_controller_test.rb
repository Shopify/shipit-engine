require 'test_helper'

class WebhooksControllerTest < ActionController::TestCase
  setup do
    @stack = stacks(:shipit)
  end

  test ":push with the target branch queues a job" do
    Resque.expects(:enqueue).with(GithubSyncJob, stack_id: @stack.id)
    Resque.expects(:enqueue).with(GitMirrorUpdateJob, stack_id: @stack.id)
    params = {"payload"=>"{\"ref\":\"refs/heads/master\",\"after\":\"435b9937f2774b351adb06412c9fac3e477134df\",\"before\":\"afa3d1edbb8689a03a2920667c0f685469fd349b\",\"created\":false,\"deleted\":false,\"forced\":false,\"compare\":\"https://github.com/gmalette/Enhance/compare/afa3d1edbb86...435b9937f277\",\"commits\":[{\"id\":\"435b9937f2774b351adb06412c9fac3e477134df\",\"distinct\":true,\"message\":\"toto\",\"timestamp\":\"2014-02-27T09:22:13-08:00\",\"url\":\"https://github.com/gmalette/Enhance/commit/435b9937f2774b351adb06412c9fac3e477134df\",\"author\":{\"name\":\"Guillaume Malette\",\"email\":\"guillaume@jadedpixel.com\",\"username\":\"gmalette\"},\"committer\":{\"name\":\"Guillaume Malette\",\"email\":\"guillaume@jadedpixel.com\",\"username\":\"gmalette\"},\"added\":[],\"removed\":[],\"modified\":[]}],\"head_commit\":{\"id\":\"435b9937f2774b351adb06412c9fac3e477134df\",\"distinct\":true,\"message\":\"toto\",\"timestamp\":\"2014-02-27T09:22:13-08:00\",\"url\":\"https://github.com/gmalette/Enhance/commit/435b9937f2774b351adb06412c9fac3e477134df\",\"author\":{\"name\":\"Guillaume Malette\",\"email\":\"guillaume@jadedpixel.com\",\"username\":\"gmalette\"},\"committer\":{\"name\":\"Guillaume Malette\",\"email\":\"guillaume@jadedpixel.com\",\"username\":\"gmalette\"},\"added\":[],\"removed\":[],\"modified\":[]},\"repository\":{\"id\":2284946,\"name\":\"Enhance\",\"url\":\"https://github.com/gmalette/Enhance\",\"description\":\"Rack middleware to resize images\",\"homepage\":\"\",\"watchers\":4,\"stargazers\":4,\"forks\":1,\"fork\":false,\"size\":278,\"owner\":{\"name\":\"gmalette\",\"email\":\"gmalette@gmail.com\"},\"private\":false,\"open_issues\":0,\"has_issues\":true,\"has_downloads\":true,\"has_wiki\":true,\"language\":\"Ruby\",\"created_at\":1314563387,\"pushed_at\":1393521739,\"master_branch\":\"master\"},\"pusher\":{\"name\":\"gmalette\",\"email\":\"gmalette@gmail.com\"}}", "action"=>"create", "controller"=>"webhooks"}
    post :push, { stack_id: @stack.id }.merge(params)
  end

  test ":push does not enqueue a job if not the target branch" do
    Resque.expects(:enqueue).never
    params = {"payload"=>"{\"ref\":\"refs/heads/not-master\",\"after\":\"435b9937f2774b351adb06412c9fac3e477134df\",\"before\":\"afa3d1edbb8689a03a2920667c0f685469fd349b\",\"created\":false,\"deleted\":false,\"forced\":false,\"compare\":\"https://github.com/gmalette/Enhance/compare/afa3d1edbb86...435b9937f277\",\"commits\":[{\"id\":\"435b9937f2774b351adb06412c9fac3e477134df\",\"distinct\":true,\"message\":\"toto\",\"timestamp\":\"2014-02-27T09:22:13-08:00\",\"url\":\"https://github.com/gmalette/Enhance/commit/435b9937f2774b351adb06412c9fac3e477134df\",\"author\":{\"name\":\"Guillaume Malette\",\"email\":\"guillaume@jadedpixel.com\",\"username\":\"gmalette\"},\"committer\":{\"name\":\"Guillaume Malette\",\"email\":\"guillaume@jadedpixel.com\",\"username\":\"gmalette\"},\"added\":[],\"removed\":[],\"modified\":[]}],\"head_commit\":{\"id\":\"435b9937f2774b351adb06412c9fac3e477134df\",\"distinct\":true,\"message\":\"toto\",\"timestamp\":\"2014-02-27T09:22:13-08:00\",\"url\":\"https://github.com/gmalette/Enhance/commit/435b9937f2774b351adb06412c9fac3e477134df\",\"author\":{\"name\":\"Guillaume Malette\",\"email\":\"guillaume@jadedpixel.com\",\"username\":\"gmalette\"},\"committer\":{\"name\":\"Guillaume Malette\",\"email\":\"guillaume@jadedpixel.com\",\"username\":\"gmalette\"},\"added\":[],\"removed\":[],\"modified\":[]},\"repository\":{\"id\":2284946,\"name\":\"Enhance\",\"url\":\"https://github.com/gmalette/Enhance\",\"description\":\"Rack middleware to resize images\",\"homepage\":\"\",\"watchers\":4,\"stargazers\":4,\"forks\":1,\"fork\":false,\"size\":278,\"owner\":{\"name\":\"gmalette\",\"email\":\"gmalette@gmail.com\"},\"private\":false,\"open_issues\":0,\"has_issues\":true,\"has_downloads\":true,\"has_wiki\":true,\"language\":\"Ruby\",\"created_at\":1314563387,\"pushed_at\":1393521739,\"master_branch\":\"master\"},\"pusher\":{\"name\":\"gmalette\",\"email\":\"gmalette@gmail.com\"}}", "action"=>"create", "controller"=>"webhooks"}
    post :push, { stack_id: @stack.id }.merge(params)
  end

  test ":status updates the commit with the payload state" do
    commit = commits(:first)
    params = {"payload" => "{\"sha\":\"#{commit.sha}\", \"state\":\"pending\"}"}
    post :state, { stack_id: @stack.id }.merge(params)

    assert_equal 'pending', commit.reload.state
  end
end
