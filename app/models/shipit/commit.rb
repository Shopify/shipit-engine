# typed: false
module Shipit
  class Commit < ActiveRecord::Base
    include DeferredTouch

    RECENT_COMMIT_THRESHOLD = 10.seconds

    AmbiguousRevision = Class.new(StandardError)

    belongs_to :stack
    has_many :deploys
    has_many :statuses, -> { order(created_at: :desc) }, dependent: :destroy, inverse_of: :commit
    has_many :check_runs, -> { order(created_at: :desc) }, dependent: :destroy, inverse_of: :commit
    has_many :commit_deployments, dependent: :destroy
    has_many :release_statuses, dependent: :destroy
    belongs_to :pull_request, inverse_of: :merge_commit, optional: true

    deferred_touch stack: :updated_at

    before_create :identify_pull_request
    after_commit { broadcast_update }
    after_create { stack.update_undeployed_commits_count }

    after_commit :schedule_refresh_statuses!, :schedule_refresh_check_runs!, :schedule_fetch_stats!,
                 :schedule_continuous_delivery, on: :create

    belongs_to :author, class_name: 'User', inverse_of: :authored_commits
    belongs_to :committer, class_name: 'User', inverse_of: :commits
    belongs_to :lock_author, class_name: :User, optional: true, inverse_of: false

    def author
      super || AnonymousUser.new
    end

    def committer
      super || AnonymousUser.new
    end

    def lock_author
      super || AnonymousUser.new
    end

    scope :reachable, -> { where(detached: false) }

    delegate :broadcast_update, :github_repo_name, :hidden_statuses, :required_statuses, :blocking_statuses,
             :soft_failing_statuses, to: :stack

    def self.newer_than(commit)
      return all unless commit
      where('id > ?', commit.try(:id) || commit)
    end

    def self.older_than(commit)
      return all unless commit
      where('id < ?', commit.try(:id) || commit)
    end

    def self.since(commit)
      return all unless commit
      where('id >= ?', commit.try(:id) || commit)
    end

    def self.until(commit)
      return all unless commit
      where('id <= ?', commit.try(:id) || commit)
    end

    def self.successful
      preload(:statuses).to_a.select(&:success?)
    end

    def self.detach!
      Commit.where(id: ids).update_all(detached: true)
    end

    def self.by_sha(sha)
      if sha.to_s.size < 6
        raise AmbiguousRevision, "Short SHA1 #{sha} is ambiguous (too short)"
      end

      commits = where('sha like ?', "#{sha}%").take(2)
      raise AmbiguousRevision, "Short SHA1 #{sha} is ambiguous (matches multiple commits)" if commits.size > 1
      commits.first
    end

    def self.by_sha!(sha)
      by_sha(sha) || raise(ActiveRecord::RecordNotFound, "Couldn't find commit with sha #{sha}")
    end

    def self.from_github(commit)
      author = User.find_or_create_author_from_github_commit(commit)
      author ||= Anonymous.new
      committer = User.find_or_create_committer_from_github_commit(commit)
      committer ||= Anonymous.new

      new(
        sha: commit.sha,
        message: commit.commit.message,
        author:  author,
        committer: committer,
        committed_at: commit.commit.committer.date,
        authored_at: commit.commit.author.date,
        additions: commit.stats&.additions,
        deletions: commit.stats&.deletions,
      )
    end

    def message=(message)
      limit = self.class.columns_hash['message'].limit
      if limit && message && message.size > limit
        message = message.slice(0, limit)
      end
      super(message)
    end

    def reload(*)
      @status = nil
      super
    end

    def self.create_from_github!(commit, extra_attributes = {})
      record = from_github(commit)
      record.update!(extra_attributes)
      record
    end

    def statuses_and_check_runs
      statuses + check_runs
    end

    def schedule_refresh_statuses!
      RefreshStatusesJob.perform_later(commit_id: id)
    end

    def schedule_refresh_check_runs!
      RefreshCheckRunsJob.perform_later(commit_id: id)
    end

    def refresh_statuses!
      github_statuses = stack.handle_github_redirections do
        Shipit.github.api.statuses(github_repo_name, sha, per_page: 100)
      end
      github_statuses.each do |status|
        create_status_from_github!(status)
      end
    end

    def create_status_from_github!(github_status)
      add_status do
        statuses.replicate_from_github!(stack_id, github_status)
      end
    end

    def refresh_check_runs!
      response = stack.handle_github_redirections do
        Shipit.github.api.check_runs(github_repo_name, sha)
      end
      response.check_runs.each do |check_run|
        create_or_update_check_run_from_github!(check_run)
      end
    end

    def create_or_update_check_run_from_github!(github_check_run)
      check_runs.create_or_update_from_github!(stack_id, github_check_run)
    end

    def last_release_status
      @last_release_status ||= release_statuses.last || Status::Unknown.new(self)
    end

    def create_release_status!(state, user: nil, target_url: nil, description: nil)
      return unless stack.release_status?

      @last_release_status = nil
      release_statuses.create!(
        stack: stack,
        user: user,
        state: state,
        target_url: target_url,
        description: description,
      )
    end

    def checks
      @checks ||= CommitChecks.new(self)
    end

    delegate :pending?, :success?, :error?, :failure?, :blocking?, :state, to: :status

    def active?
      return false unless stack.active_task?

      stack.active_task.includes_commit?(self)
    end

    def deployable?
      !locked? && (stack.ignore_ci? || (success? && !blocked?))
    end

    def blocked?
      return false if stack.blocking_statuses.empty?

      # TODO: Perfs might be horrible here if the range is big.
      # We should look at fetching the undeployed commits only once
      stack.commits.reachable.newer_than(stack.last_deployed_commit).older_than(self).any?(&:blocking?)
    end

    def children
      self.class.where(stack_id: stack_id).newer_than(self)
    end

    def detach_children!
      children.detach!
    end

    def pull_request?
      pull_request_number.present?
    end

    # TODO: remove in a few versions when it is assumed the commits table was backfilled
    def pull_request_number
      super || message_parser.pull_request_number
    end

    def title
      pull_request_title || message_header
    end

    def message_header
      message.lines.first.to_s.strip
    end

    # TODO: remove in a few versions when it is assumed the commits table was backfilled
    def pull_request_title
      super || message_parser.pull_request_title
    end

    def revert?
      title.start_with?('Revert "') && title.end_with?('"')
    end

    def revert_of?(commit)
      title == %(Revert "#{commit.title}") || title == %(Revert "#{commit.message_header}")
    end

    def short_sha
      sha[0..9]
    end

    def schedule_continuous_delivery
      return unless deployable? && stack.continuous_deployment? && stack.deployable?
      # This buffer is to allow for statuses and checks to be refreshed before evaluating if the commit is deployable
      # - e.g. if the commit was fast-forwarded with already passing CI.
      ContinuousDeliveryJob.set(wait: RECENT_COMMIT_THRESHOLD).perform_later(stack)
    end

    def github_commit
      @github_commit ||= Shipit.github.api.commit(github_repo_name, sha)
    end

    def schedule_fetch_stats!
      FetchCommitStatsJob.perform_later(self)
    end

    def fetch_stats!
      update!(
        additions: github_commit.stats&.additions,
        deletions: github_commit.stats&.deletions,
      )
    end

    def status
      @status ||= Status::Group.compact(self, statuses_and_check_runs)
    end

    def deployed?
      stack.last_deployed_commit.id >= id
    end

    def deploy_failed?
      stack.deploys.unsuccessful.where(until_commit_id: id).any?
    end

    def identify_pull_request
      return unless message_parser.pull_request?
      if pull_request = stack.pull_requests.find_by(number: message_parser.pull_request_number)
        self.pull_request = pull_request
        self.pull_request_number = pull_request.number
        self.pull_request_title = pull_request.title
        self.author = pull_request.merge_requested_by if pull_request.merge_requested_by
      end

      self.pull_request_number = message_parser.pull_request_number unless self[:pull_request_number]
      self.pull_request_title = message_parser.pull_request_title unless self[:pull_request_title]
    end

    def deploy_requested_at
      if pull_request&.merged?
        pull_request.merge_requested_at
      else
        created_at
      end
    end

    def lock(user)
      update!(
        locked: true,
        lock_author_id: user.id,
      )
    end

    def self.lock_all(user)
      update_all(
        locked: true,
        lock_author_id: user.id,
      )
    end

    def unlock
      update!(locked: false, lock_author: nil)
    end

    def recently_pushed?
      created_at > RECENT_COMMIT_THRESHOLD.ago
    end

    private

    def message_parser
      @message_parser ||= CommitMessage.new(message)
    end

    def add_status
      already_deployed = deployed?

      previous_status = status
      yield
      reload # to get the statuses into the right order (since sorted :desc)
      new_status = status

      unless already_deployed
        payload = {commit: self, stack: stack, status: new_status.state}
        if previous_status != new_status
          Hook.emit(:commit_status, stack, payload.merge(commit_status: new_status))
        end
      end

      if previous_status.simple_state != new_status.simple_state
        if !already_deployed && (!new_status.pending? || previous_status.unknown?)
          Hook.emit(:deployable_status, stack, payload.merge(deployable_status: new_status))
        end
        if new_status.pending? || new_status.success?
          stack.schedule_merges
        end
      end
      new_status
    end
  end
end
