require 'fileutils'

class Stack < ActiveRecord::Base
  STACKS_PATH = File.join(Rails.root, "data", "stacks")
  REQUIRED_HOOKS = %w( push status )

  has_many :commits
  has_many :deploys
  has_many :webhooks

  after_create :setup_webhooks, :sync_github
  after_destroy :teardown_webhooks, :clear_local_files
  after_commit :bump_menu_cache, on: %i(create destroy)
  after_commit :broadcast_update, on: :update

  validates :repo_owner, :repo_name, presence: true, format: {with: /\A[a-z0-9_\-\.]+\z/}
  validates :environment, presence: true, format: {with: /\A[a-z0-9\-_]+\z/}

  def trigger_deploy(until_commit, user)
    since_commit = last_deployed_commit

    deploy = deploys.create(
      user_id: user.id,
      until_commit: until_commit,
      since_commit: since_commit
    )
    deploy.enqueue
    deploy
  end

  def last_deployed_commit
    if last_deploy = deploys.success.last
      last_deploy.until_commit
    else
      commits.first
    end
  end

  def repo_name=(name)
    super(name.try(:downcase))
  end

  def repo_owner=(name)
    super(name.try(:downcase))
  end

  def repo_http_url
    "https://github.com/#{repo_owner}/#{repo_name}"
  end

  def repo_git_url
    "git@github.com:#{repo_owner}/#{repo_name}.git"
  end

  def base_path
    File.join(STACKS_PATH, repo_owner, repo_name, environment)
  end

  def deploys_path
    File.join(base_path, "deploys")
  end

  def git_path
    File.join(base_path, "git")
  end

  def github_repo_name
    return [repo_owner, repo_name].join('/')
  end

  def github_repo
    Shipit.github_api.repo(github_repo_name)
  end

  def github_commits
    Shipit.github_api.commits(github_repo_name, sha: branch)
    Shipit.github_api.last_response
  end

  def locked?
    lock_reason.present?
  end

  def to_param
    [repo_owner, repo_name, environment].join('/')
  end

  def self.from_param(param)
    repo_owner, repo_name, environment = param.split('/')
    where(
      :repo_owner  => repo_owner.downcase,
      :repo_name   => repo_name.downcase,
      :environment => environment
    ).first!
  end

  def checks
    checklist.to_s.lines.map(&:strip).select(&:present?)
  end

  private

  def setup_webhooks
    Resque.enqueue(GithubSetupWebhooksJob, stack_id: id)
  end

  def teardown_webhooks
    Resque.enqueue(GithubTeardownWebhooksJob, stack_id: id, github_repo_name: github_repo_name)
  end

  def sync_github
    Resque.enqueue(GithubSyncJob, stack_id: id)
  end

  def bump_menu_cache
    Menu.bump_cache
  end

  def clear_local_files
    FileUtils.rm_rf(base_path)
  end

  def broadcast_update
    payload = {id: id, locked: lock_reason.present?}.to_json
    event = Pubsubstub::Event.new(payload, name: "stack.update")
    Pubsubstub::RedisPubSub.publish("stack.#{id}", event)
  end
end
