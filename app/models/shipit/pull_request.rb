module Shipit
  class PullRequest < ApplicationRecord
    include DeferredTouch

    WAITING_STATUSES = %w(fetching pending).freeze
    REJECTION_REASONS = %w(ci_failing merge_conflict expired).freeze
    InvalidTransition = Class.new(StandardError)
    NotReady = Class.new(StandardError)

    class StatusChecker < Status::Group
      def initialize(commit, statuses, deploy_spec)
        @deploy_spec = deploy_spec
        super(commit, statuses)
      end

      private

      attr_reader :deploy_spec

      def reject_hidden(statuses)
        statuses.reject { |s| ignored_statuses.include?(s.context) }
      end

      def reject_allowed_to_fail(statuses)
        statuses.reject { |s| ignored_statuses.include?(s.context) }
      end

      def ignored_statuses
        deploy_spec.try!(:pull_request_ignored_statuses) || []
      end

      def required_statuses
        deploy_spec.try!(:pull_request_required_statuses) || []
      end
    end

    belongs_to :stack
    belongs_to :head, class_name: 'Shipit::Commit'
    belongs_to :merge_requested_by, class_name: 'Shipit::User'
    has_one :merge_commit, class_name: 'Shipit::Commit'

    deferred_touch stack: :updated_at

    validates :number, presence: true, uniqueness: {scope: :stack_id}

    scope :waiting, -> { where(merge_status: WAITING_STATUSES) }
    scope :pending, -> { where(merge_status: 'pending') }
    scope :to_be_merged, -> { pending.order(merge_requested_at: :asc) }

    after_save :record_merge_status_change
    after_commit :emit_hooks

    state_machine :merge_status, initial: :fetching do
      state :fetching
      state :pending
      state :rejected
      state :canceled
      state :merged

      event :fetched do
        transition fetching: :pending
      end

      event :reject do
        transition pending: :rejected
      end

      event :cancel do
        transition any => :canceled
      end

      event :complete do
        transition pending: :merged
      end

      event :retry do
        transition %i(rejected canceled) => :pending
      end

      before_transition rejected: any do |pr|
        pr.rejection_reason = nil
      end
    end

    def self.schedule_merges
      Shipit::Stack.where(id: pending.uniq.pluck(:stack_id)).find_each(&:schedule_merges)
    end

    def self.request_merge!(stack, number, user)
      now = Time.now.utc
      pull_request = begin
        create_with(
          merge_requested_at: now,
          merge_requested_by: user.presence,
        ).find_or_create_by!(
          stack: stack,
          number: number,
        )
      rescue ActiveRecord::RecordNotUnique
        retry
      end
      pull_request.update!(merge_requested_at: now, merge_requested_by: user.presence)
      pull_request.retry! if pull_request.rejected? || pull_request.canceled?
      pull_request.schedule_refresh!
      pull_request
    end

    def reject!(reason)
      unless REJECTION_REASONS.include?(reason)
        raise ArgumentError, "invalid reason: #{reason.inspect}, must be one of: #{REJECTION_REASONS.inspect}"
      end
      self.rejection_reason = reason.presence
      super()
      true
    end

    def reject_unless_mergeable!
      return reject!('merge_conflict') if merge_conflict?
      return reject!('ci_failing') unless all_status_checks_passed?
      false
    end

    def merge!
      raise InvalidTransition unless pending?

      raise NotReady if not_mergeable_yet?
      if need_revalidation?
        reject!('expired')
        return false
      end

      Shipit.github_api.merge_pull_request(
        stack.github_repo_name,
        number,
        merge_message,
        sha: head.sha,
        commit_message: 'Merged by Shipit',
        merge_method: 'merge',
      )
      begin
        Shipit.github_api.delete_branch(stack.github_repo_name, branch)
      rescue Octokit::UnprocessableEntity
        # branch was already deleted somehow
      end
      complete!
      return true
    rescue Octokit::MethodNotAllowed # merge conflict
      reject!('merge_conflict')
      return false
    rescue Octokit::Conflict # shas didn't match, PR was updated.
      raise NotReady
    end

    def all_status_checks_passed?
      StatusChecker.new(head, head.statuses, stack.cached_deploy_spec).success?
    end

    def waiting?
      WAITING_STATUSES.include?(merge_status)
    end

    def need_revalidation?
      timeout = stack.cached_deploy_spec.try!(:revalidate_pull_requests_after)
      return false unless timeout
      (merge_requested_at + timeout).past?
    end

    def merge_conflict?
      mergeable == false
    end

    def not_mergeable_yet?
      mergeable.nil?
    end

    def schedule_refresh!
      RefreshPullRequestJob.perform_later(self)
    end

    def refresh!
      update!(github_pull_request: Shipit.github_api.pull_request(stack.github_repo_name, number))
      head.refresh_statuses!
      fetched! if fetching?
    end

    def github_pull_request=(github_pull_request)
      self.github_id = github_pull_request.id
      self.api_url = github_pull_request.url
      self.title = github_pull_request.title
      self.state = github_pull_request.state
      self.mergeable = github_pull_request.mergeable
      self.additions = github_pull_request.additions
      self.deletions = github_pull_request.deletions
      self.branch = github_pull_request.head.ref
      self.head = find_or_create_commit_from_github_by_sha!(github_pull_request.head.sha, detached: true)
    end

    def merge_message
      return title unless merge_requested_by
      "#{title}\n\nMerge-Requested-By: #{merge_requested_by.login}\n"
    end

    private

    def record_merge_status_change
      @merge_status_changed ||= merge_status_changed?
    end

    def emit_hooks
      return unless @merge_status_changed
      @merge_status_changed = nil
      Hook.emit('merge', stack, pull_request: self, status: merge_status, stack: stack)
    end

    def find_or_create_commit_from_github_by_sha!(sha, attributes)
      if commit = stack.commits.by_sha(sha)
        return commit
      else
        github_commit = Shipit.github_api.commit(stack.github_repo_name, sha)
        stack.commits.create_from_github!(github_commit, attributes)
      end
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end
end
