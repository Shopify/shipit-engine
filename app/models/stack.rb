require 'fileutils'

class Stack < ActiveRecord::Base
  REQUIRED_HOOKS = %i(push status)

  has_many :commits, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :deploys
  has_many :rollbacks
  has_many :deploys_and_rollbacks, -> { where(type: %w(Deploy Rollback)) }, class_name: 'Task'
  has_many :github_hooks, dependent: :destroy, class_name: 'GithubHook::Repo'
  has_many :hooks, dependent: :destroy
  has_many :api_clients, dependent: :destroy
  belongs_to :lock_author, class_name: :User

  def lock_author(*)
    super || AnonymousUser.new
  end

  before_validation :update_defaults
  before_destroy :clear_local_files
  after_commit :emit_hooks
  after_commit :broadcast_update, on: :update
  after_commit :setup_hooks, :sync_github, on: :create
  after_touch :clear_cache

  validates :repo_name, uniqueness: {scope: %i(repo_owner environment)}
  validates :repo_owner, :repo_name, presence: true, format: {with: /\A[a-z0-9_\-\.]+\z/}
  validates :environment, presence: true, format: {with: /\A[a-z0-9\-_\:]+\z/}

  serialize :cached_deploy_spec, DeploySpec
  delegate :find_task_definition, :supports_rollback?,
           :supports_fetch_deployed_revision?, to: :cached_deploy_spec, allow_nil: true

  def self.refresh_deployed_revisions
    find_each.select(&:supports_fetch_deployed_revision?).each(&:async_refresh_deployed_revision)
  end

  def undeployed_commits?
    undeployed_commits_count > 0
  end

  def trigger_task(definition_id, user)
    commit = last_deployed_commit
    task = tasks.create(
      user_id: user.id,
      definition: find_task_definition(definition_id),
      until_commit_id: commit.id,
      since_commit_id: commit.id,
    )
    task.enqueue
    task
  end

  def trigger_deploy(until_commit, user, env: nil)
    since_commit = last_deployed_commit

    deploy = deploys.create(
      user_id: user.id,
      until_commit: until_commit,
      since_commit: since_commit,
      env: env || {},
    )
    deploy.enqueue
    deploy
  end

  def async_refresh_deployed_revision
    FetchDeployedRevisionJob.perform_later(self)
  end

  def update_deployed_revision(sha)
    return if deploying?

    last_deploy = deploys_and_rollbacks.last
    actual_deployed_commit = commits.reachable.by_sha!(sha)

    if actual_deployed_commit == last_deploy.until_commit
      last_deploy.accept!
    elsif actual_deployed_commit == last_deploy.since_commit
      last_deploy.reject!
    else
      deploys.create!(
        until_commit: actual_deployed_commit,
        since_commit: last_deployed_commit,
        status: 'success',
      )
    end
  end

  def head
    commits.reachable.first.try!(:sha)
  end

  def status
    return :deploying if deploying?
    :default
  end

  def last_successful_deploy
    deploys_and_rollbacks.success.order(created_at: :desc).first
  end

  def last_deployed_commit
    if deploy = last_successful_deploy
      deploy.until_commit
    else
      commits.first
    end
  end

  def filter_visible_statuses(statuses)
    statuses.reject { |s| hidden_statuses.include?(s.context) }
  end

  def filter_meaningful_statuses(statuses)
    filter_visible_statuses(statuses).reject { |s| soft_failing_statuses.include?(s.context) }
  end

  def deployable?
    !locked? && !deploying?
  end

  def repo_name=(name)
    super(name.try(:downcase))
  end

  def repo_owner=(name)
    super(name.try(:downcase))
  end

  def repo_http_url
    Shipit.github_url("#{repo_owner}/#{repo_name}")
  end

  def repo_git_url
    "git@#{Shipit.github_domain}:#{repo_owner}/#{repo_name}.git"
  end

  def base_path
    Rails.root.join('data/stacks', repo_owner, repo_name, environment)
  end

  def deploys_path
    File.join(base_path, "deploys")
  end

  def git_path
    File.join(base_path, "git")
  end

  def acquire_git_cache_lock(timeout: 15, &block)
    Redis::Lock.new(
      "stack:#{id}:git-cache-lock",
      Shipit.redis,
      timeout: timeout,
      expiration: 60,
    ).lock(&block)
  end

  def clear_git_cache!
    tmp_path = "#{git_path}-#{SecureRandom.hex}"
    acquire_git_cache_lock do
      return unless File.exist?(git_path)
      File.rename(git_path, tmp_path)
    end
    FileUtils.rm_rf(tmp_path)
  end

  def github_repo_name
    [repo_owner, repo_name].join('/')
  end

  def github_commits
    handle_github_errors { Shipit.github_api.commits(github_repo_name, sha: branch) }
  end

  def deploying?
    !!active_deploy
  end

  def active_deploy
    return @active_deploy if defined?(@active_deploy)
    @active_deploy ||= deploys_and_rollbacks.active.last
  end

  def locked?
    lock_reason.present?
  end

  def to_param
    [repo_owner, repo_name, environment].join('/')
  end

  def self.from_param!(param)
    repo_owner, repo_name, environment = param.split('/')
    where(
      repo_owner: repo_owner.downcase,
      repo_name: repo_name.downcase,
      environment: environment,
    ).first!
  end

  delegate :plugins, :task_definitions, :hidden_statuses, :soft_failing_statuses,
           :deploy_variables, to: :cached_deploy_spec

  def monitoring?
    monitoring.present?
  end

  def monitoring
    cached_deploy_spec.review_monitoring
  end

  def checklist
    cached_deploy_spec.review_checklist
  end

  def checks?
    cached_deploy_spec.review_checks.present?
  end

  def update_undeployed_commits_count(after_commit = nil)
    after_commit ||= last_deployed_commit
    undeployed_commits = commits.reachable.select('count(*) as count').where('id > ?', after_commit.id)
    self.class.where(id: id).update_all("undeployed_commits_count = (#{undeployed_commits.to_sql})")
  end

  def broadcast_update
    payload = {url: Shipit::Engine.routes.url_helpers.stack_path(self)}.to_json
    event = Pubsubstub::Event.new(payload, name: "stack.update")
    Pubsubstub::RedisPubSub.publish("stack.#{id}", event)
  end

  def setup_hooks
    REQUIRED_HOOKS.each do |event|
      hook = github_hooks.find_or_create_by!(event: event)
      hook.schedule_setup!
    end
  end

  def schedule_for_destroy!
    DestroyStackJob.perform_later(self)
  end

  def ci_enabled?
    Rails.cache.fetch(ci_enabled_cache_key) do
      commits.joins(:statuses).any?
    end
  end

  def enable_ci!
    Rails.cache.write(ci_enabled_cache_key, true)
  end

  def mark_as_accessible!
    update!(inaccessible_since: nil)
  end

  def mark_as_inaccessible!
    update!(inaccessible_since: Time.now) unless inaccessible?
  end

  def inaccessible?
    inaccessible_since?
  end

  private

  def handle_github_errors
    resource = yield
    if resource.try(:message) == 'Moved Permanently'
      update_repository_name_from_github!
      resource = yield
    end
    resource
  end

  def update_repository_name_from_github!
    response = Shipit.github_api.repo(github_repo_name)
    repository = Shipit.github_api.get(response.url)
    update!(repo_name: repository.name, repo_owner: repository.owner.login)
  end

  def clear_cache
    remove_instance_variable(:@active_deploy) if defined?(@active_deploy)
  end

  def sync_github
    GithubSyncJob.perform_later(stack_id: id)
  end

  def clear_local_files
    FileUtils.rm_rf(base_path.to_s)
  end

  def update_defaults
    self.environment = 'production' if environment.blank?
    self.branch = 'master' if branch.blank?
  end

  def emit_hooks
    return unless previous_changes.include?('lock_reason')
    Hook.emit(:lock, self, locked: locked?, stack: self)
  end

  def ci_enabled_cache_key
    "stacks:#{id}:ci_enabled"
  end
end
