require 'fileutils'

module Shipit
  class Stack < ActiveRecord::Base
    module NoDeployedCommit
      extend self

      def id
        -1
      end

      def sha
        ''
      end

      def short_sha
        ''
      end

      def blank?
        true
      end
    end

    ENVIRONMENT_MAX_SIZE = 50
    REQUIRED_HOOKS = %i(push status).freeze

    has_many :commits, dependent: :destroy
    has_many :pull_requests, dependent: :destroy
    has_many :tasks, dependent: :destroy
    has_many :deploys
    has_many :rollbacks
    has_many :deploys_and_rollbacks,
             -> { where(type: %w(Shipit::Deploy Shipit::Rollback)) },
             class_name: 'Task',
             inverse_of: :stack
    has_many :github_hooks, dependent: :destroy, class_name: 'Shipit::GithubHook::Repo'
    has_many :hooks, dependent: :destroy
    has_many :api_clients, dependent: :destroy
    belongs_to :lock_author, class_name: :User, optional: true
    belongs_to :repository
    validates_associated :repository

    scope :not_archived, -> { where(archived_since: nil) }
    scope :locked_because, ->(reason_code) { where(lock_reason_code: reason_code) }
    scope :auto_provisioned, -> { where(auto_provisioned: true) }

    include DeferredTouch
    deferred_touch repository: :updated_at

    def repository
      super || build_repository
    end

    def lock_author(*)
      super || AnonymousUser.new
    end

    def lock_author=(user)
      super(user&.logged_in? ? user : nil)
    end

    before_validation :update_defaults
    before_destroy :clear_local_files
    before_save :set_locked_since
    after_commit :emit_lock_hooks
    after_commit :emit_added_hooks, on: :create
    after_commit :emit_updated_hooks, on: :update
    after_commit :emit_removed_hooks, on: :destroy
    after_commit :broadcast_update, on: :update
    after_commit :emit_merge_status_hooks, on: :update
    after_commit :sync_github, on: :create
    after_commit :schedule_merges_if_necessary, on: :update

    validates :repository, uniqueness: {
      scope: %i(environment), case_sensitive: false,
      message: 'cannot be used more than once with this environment. Check archived stacks.'
    }
    validates :environment, format: {with: /\A[a-z0-9\-_\:]+\z/}, length: {maximum: ENVIRONMENT_MAX_SIZE}
    validates :deploy_url, format: {with: URI.regexp(%w(http https ssh))}, allow_blank: true

    validates :lock_reason, length: {maximum: 4096}

    serialize :cached_deploy_spec, DeploySpec
    delegate :find_task_definition, :supports_rollback?, :links, :release_status?, :release_status_delay,
             :release_status_context, :supports_fetch_deployed_revision?, to: :cached_deploy_spec, allow_nil: true

    def self.refresh_deployed_revisions
      find_each.select(&:supports_fetch_deployed_revision?).each(&:async_refresh_deployed_revision)
    end

    def self.schedule_continuous_delivery
      where(continuous_deployment: true).find_each do |stack|
        ContinuousDeliveryJob.perform_later(stack)
      end
    end

    def undeployed_commits?
      undeployed_commits_count > 0
    end

    def trigger_task(definition_id, user, env: nil, force: false)
      definition = find_task_definition(definition_id)
      env = env&.to_h || {}

      definition.variables_with_defaults.each do |variable|
        env[variable.name] ||= variable.default
      end

      commit = last_deployed_commit.presence || commits.first
      task = tasks.create(
        user_id: user.id,
        definition: definition,
        until_commit_id: commit.id,
        since_commit_id: commit.id,
        env: definition.filter_envs(env),
        allow_concurrency: definition.allow_concurrency? || force,
        ignored_safeties: force,
      )
      task.enqueue
      task
    end

    def build_deploy(until_commit, user, env: nil, force: false)
      since_commit = last_deployed_commit.presence || commits.first
      deploys.build(
        user_id: user.id,
        until_commit: until_commit,
        since_commit: since_commit,
        env: filter_deploy_envs(env&.to_h || {}),
        allow_concurrency: force,
        ignored_safeties: force || !until_commit.deployable?,
      )
    end

    def trigger_deploy(*args, **kwargs)
      run_now = kwargs.delete(:run_now)
      deploy = build_deploy(*args, **kwargs)
      deploy.save!
      run_now ? deploy.run_now! : deploy.enqueue
      continuous_delivery_resumed!
      deploy
    end

    def continuous_delivery_resumed!
      update!(continuous_delivery_delayed_since: nil)
    end

    def continuous_delivery_delayed?
      continuous_delivery_delayed_since? && continuous_deployment? && checks?
    end

    def continuous_delivery_delayed!
      touch(:continuous_delivery_delayed_since) unless continuous_delivery_delayed?
    end

    def trigger_continuous_delivery
      commit = next_commit_to_deploy

      if !deployable? || deployed_too_recently? || commit.nil? || commit.deployed?
        continuous_delivery_resumed!
        return
      end

      if commit.deploy_failed? || (checks? && !EphemeralCommitChecks.new(commit).run.success?) ||
         commit.recently_pushed?
        continuous_delivery_delayed!
        return
      end

      begin
        trigger_deploy(commit, Shipit.user, env: cached_deploy_spec.default_deploy_env)
      rescue Task::ConcurrentTaskRunning
      end
    end

    def schedule_merges
      MergePullRequestsJob.perform_later(self)
    end

    def next_commit_to_deploy
      commits_to_deploy = commits.order(id: :asc).newer_than(last_deployed_commit).reachable.preload(:statuses)
      commits_to_deploy = commits_to_deploy.limit(maximum_commits_per_deploy) if maximum_commits_per_deploy
      commits_to_deploy.to_a.reverse.find(&:deployable?)
    end

    def deployed_too_recently?
      if task = last_active_task
        return true if task.validating?

        task.ended_at? && (task.ended_at + pause_between_deploys).future?
      end
    end

    def async_refresh_deployed_revision
      async_refresh_deployed_revision!
    rescue => error
      logger.warn "Failed to dispatch FetchDeployedRevisionJob: [#{error.class.name}] #{error.message}"
    end

    def async_refresh_deployed_revision!
      FetchDeployedRevisionJob.perform_later(self)
    end

    def update_deployed_revision(sha)
      last_deploy = deploys_and_rollbacks.last
      return if last_deploy&.active?

      actual_deployed_commit = commits.reachable.by_sha(sha)
      return unless actual_deployed_commit

      if last_deploy && actual_deployed_commit == last_deploy.until_commit
        last_deploy.accept!
      elsif last_deploy && actual_deployed_commit == last_deploy.since_commit
        last_deploy.reject!
      else
        deploys.create!(
          until_commit: actual_deployed_commit,
          since_commit: last_deployed_commit.presence || commits.first,
          status: 'success',
        )
      end
    end

    def head
      commits.reachable.first&.sha
    end

    def merge_status(backlog_leniency_factor: 2.0)
      return 'locked' if locked?
      return 'failure' if %w(failure error).freeze.include?(branch_status)
      return 'backlogged' if backlogged?(backlog_leniency_factor: backlog_leniency_factor)
      'success'
    end

    def backlogged?(backlog_leniency_factor: 2.0)
      maximum_commits_per_deploy && (undeployed_commits_count > maximum_commits_per_deploy * backlog_leniency_factor)
    end

    def branch_status
      undeployed_commits.each do |commit|
        state = commit.status.simple_state
        return state unless %w(pending unknown missing).freeze.include?(state)
      end
      'pending'
    end

    def status
      return :deploying if active_task?
      :default
    end

    def lock_reverted_commits!
      backlog = undeployed_commits.to_a
      affected_rows = 0

      until backlog.empty?
        backlog = backlog.drop_while { |c| !c.revert? }
        revert = backlog.shift
        next if revert.nil?

        commits_to_lock = backlog.reverse.drop_while { |c| !revert.revert_of?(c) }
        next if commits_to_lock.empty?

        affected_rows += commits
                         .where(id: commits_to_lock.map(&:id).uniq)
                         .lock_all(revert.author)
      end

      touch if affected_rows > 1
    end

    def next_expected_commit_to_deploy(commits: nil)
      commits ||= undeployed_commits do |scope|
        scope.preload(:statuses, :check_runs)
      end

      commits_to_deploy = commits.reject(&:active?)
      if maximum_commits_per_deploy
        commits_to_deploy = commits_to_deploy.reverse.slice(0, maximum_commits_per_deploy).reverse
      end
      commits_to_deploy.find(&:deployable?)
    end

    def undeployed_commits
      scope = commits.reachable.newer_than(last_deployed_commit).order(id: :asc)

      scope = yield scope if block_given?

      scope.to_a.reverse
    end

    def last_completed_deploy
      deploys_and_rollbacks.last_completed
    end

    def last_successful_deploy_commit
      deploys_and_rollbacks.last_successful&.until_commit
    end

    def previous_successful_deploy(deploy_id)
      deploys_and_rollbacks.success.where("id < ?", deploy_id).last
    end

    def last_active_task
      tasks.exclusive.last
    end

    def last_deployed_commit
      last_completed_deploy&.until_commit || NoDeployedCommit
    end

    def previous_successful_deploy_commit(deploy_id)
      previous_successful_deploy(deploy_id)&.until_commit || NoDeployedCommit
    end

    def deployable?
      !locked? && !active_task?
    end

    def allows_merges?
      merge_queue_enabled? && !locked? && merge_status == 'success'
    end

    def merge_method
      cached_deploy_spec&.pull_request_merge_method || Shipit.default_merge_method
    end

    delegate :name=, to: :repository, prefix: :repo
    delegate :name, to: :repository, prefix: :repo
    delegate :owner=, to: :repository, prefix: :repo
    delegate :owner, to: :repository, prefix: :repo
    delegate :http_url, to: :repository, prefix: :repo
    delegate :git_url, to: :repository, prefix: :repo

    def base_path
      Rails.root.join('data', 'stacks', repo_owner, repo_name, environment)
    end

    def deploys_path
      File.join(base_path, "deploys")
    end

    def git_path
      File.join(base_path, "git")
    end

    def acquire_git_cache_lock(timeout: 15, &block)
      Flock.new(git_path.to_s + '.lock').lock(timeout: timeout, &block)
    end

    def clear_git_cache!
      tmp_path = "#{git_path}-#{SecureRandom.hex}"
      return unless File.exist?(git_path)
      acquire_git_cache_lock do
        File.rename(git_path, tmp_path)
      end
      FileUtils.rm_rf(tmp_path)
    end

    def github_repo_name
      repository.github_repo_name
    end

    def github_commits
      handle_github_redirections do
        Shipit.github.api.commits(github_repo_name, sha: branch)
      end
    rescue Octokit::Conflict
      [] # Repository is empty...
    end

    def handle_github_redirections
      # https://developer.github.com/v3/#http-redirects
      resource = yield
      if resource.try(:message) == 'Moved Permanently'
        refresh_repository!
        yield
      else
        resource
      end
    end

    def refresh_repository!
      resource = Shipit.github.api.repo(github_repo_name)
      if resource.try(:message) == 'Moved Permanently'
        resource = Shipit.github.api.get(resource.url)
      end
      repository.update!(owner: resource.owner.login, name: resource.name)
    end

    def active_task?
      !!active_task
    end

    def active_task
      return @active_task if defined?(@active_task)
      @active_task ||= tasks.current
    end

    def locked?
      lock_reason.present?
    end

    def lock(reason, user, code: nil)
      params = {lock_reason: reason, lock_reason_code: code, lock_author: user}
      update!(params)
    end

    def unlock
      update!(lock_reason: nil, lock_reason_code: nil, lock_author: nil, locked_since: nil)
    end

    def archived?
      archived_since.present?
    end

    def archive!(user)
      update!(archived_since: Time.now, lock_reason: "Archived", lock_reason_code: "ARCHIVED", lock_author: user)
    end

    def unarchive!
      update!(archived_since: nil, lock_reason: nil, lock_reason_code: nil, lock_author: nil, locked_since: nil)
    end

    def to_param
      [repo_owner, repo_name, environment].join('/')
    end

    def self.run_deploy_in_foreground(stack:, revision:)
      stack = Shipit::Stack.from_param!(stack)
      until_commit = stack.commits.where(sha: revision).limit(1).first
      env = stack.cached_deploy_spec.default_deploy_env
      current_user = Shipit::CommandLineUser.new

      stack.trigger_deploy(until_commit, current_user, env: env, force: true, run_now: true)
    end

    def self.from_param!(param)
      repo_owner, repo_name, environment = param.split('/')
      includes(:repository)
        .where(
          repositories: {
            owner: repo_owner.downcase,
            name: repo_name.downcase,
          },
          environment: environment,
        ).first!
    end

    delegate :plugins, :task_definitions, :hidden_statuses, :required_statuses, :soft_failing_statuses,
             :blocking_statuses, :deploy_variables, :filter_task_envs, :filter_deploy_envs,
             :maximum_commits_per_deploy, :pause_between_deploys, to: :cached_deploy_spec

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
      undeployed_commits = commits.reachable.newer_than(after_commit).count
      update(undeployed_commits_count: undeployed_commits)
    end

    def update_latest_deployed_ref
      UpdateGithubLastDeployedRefJob.perform_later(self)
    end

    def broadcast_update
      Pubsubstub.publish(
        "stack.#{id}",
        {id: id, updated_at: updated_at}.to_json,
        name: 'update',
      )
    end

    def schedule_for_destroy!
      DestroyStackJob.perform_later(self)
    end

    def ci_enabled?
      Rails.cache.fetch(ci_enabled_cache_key) do
        commits.joins(:statuses).any? || commits.joins(:check_runs).any?
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

    def reload(*)
      clear_cache
      super
    end

    def async_update_estimated_deploy_duration
      UpdateEstimatedDeployDurationJob.perform_later(self)
    end

    def update_estimated_deploy_duration!
      update!(estimated_deploy_duration: Stat.p90(recent_deploys_durations) || 1)
    end

    def recent_deploys_durations
      tasks.where(type: 'Shipit::Deploy').success.order(id: :desc).limit(100).durations
    end

    def sync_github
      GithubSyncJob.perform_later(stack_id: id)
    end

    private

    def clear_cache
      remove_instance_variable(:@active_task) if defined?(@active_task)
    end

    def clear_local_files
      FileUtils.rm_rf(base_path.to_s)
    end

    def update_defaults
      self.environment = 'production' if environment.blank?
      self.branch = 'master' if branch.blank?
    end

    def set_locked_since
      return unless lock_reason_changed?

      if lock_reason.blank?
        self.locked_since = nil
      else
        self.locked_since ||= Time.now
      end
    end

    def schedule_merges_if_necessary
      if previous_changes.include?('lock_reason') && previous_changes['lock_reason'].last.blank?
        schedule_merges
      end
    end

    def emit_lock_hooks
      return unless previous_changes.include?('lock_reason')

      lock_details = if previous_changes['lock_reason'].last.blank?
        {from: previous_changes['locked_since'].first, until: Time.zone.now}
      end

      Hook.emit(:lock, self, locked: locked?, lock_details: lock_details, stack: self)
    end

    def emit_added_hooks
      Hook.emit(:stack, self, action: :added, stack: self)
    end

    def emit_updated_hooks
      changed = !(previous_changes.keys - %w(updated_at)).empty?
      Hook.emit(:stack, self, action: :updated, stack: self) if changed
    end

    def emit_removed_hooks
      Hook.emit(:stack, self, action: :removed, stack: self)
    end

    def emit_merge_status_hooks
      Hook.emit(:merge_status, self, merge_status: merge_status, stack: self)
    end

    def ci_enabled_cache_key
      "stacks:#{id}:ci_enabled"
    end
  end
end
