# frozen_string_literal: true
module Shipit
  class MergeRequest < ApplicationRecord
    include DeferredTouch

    MERGE_REQUEST_FIELD = 'Merge-Requested-By'

    WAITING_STATUSES = %w(fetching pending).freeze
    QUEUED_STATUSES = %w(pending revalidating).freeze
    REJECTION_REASONS = %w(ci_missing ci_failing merge_conflict requires_rebase with_merge_request_issue).freeze
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
        deploy_spec&.merge_request_ignored_statuses || []
      end

      def required_statuses
        deploy_spec&.merge_request_required_statuses || []
      end
    end

    belongs_to :stack
    belongs_to :head, class_name: 'Shipit::Commit', optional: true
    belongs_to :base_commit, class_name: 'Shipit::Commit', optional: true
    belongs_to :merge_requested_by, class_name: 'Shipit::User', optional: true
    has_one :merge_commit, class_name: 'Shipit::Commit'

    has_many :predictive_merge_request
    has_many :with_merge_requests, class_name: 'Shipit::MergeRequest', foreign_key: :merge_request_id
    belongs_to :with_parent_merge_request, class_name: 'Shipit::MergeRequest', foreign_key: :merge_request_id, optional: true

    deferred_touch stack: :updated_at

    validates :number, presence: true, uniqueness: { scope: :stack_id }

    scope :root, -> { where(merge_request_id: nil) }
    scope :waiting, -> { where(merge_status: WAITING_STATUSES) }
    scope :pending, -> { where(merge_status: 'pending') }
    scope :to_be_merged, -> { pending.root.order(merge_requested_at: :asc) }
    scope :queued, -> { where(merge_status: QUEUED_STATUSES).order(merge_requested_at: :asc) }

    scope :mode, ->(mode) {
      where(:mode => mode)
    }

    def with_all
      ([self] + with_merge_requests).each do |merge_request|
        yield merge_request
      end
    end

    def root?
      !with_parent_merge_request
    end

    after_save :record_merge_status_change
    after_commit :emit_hooks

    state_machine :merge_status, initial: :fetching do
      state :fetching
      state :pending
      state :rejected
      state :canceled
      state :merged
      state :revalidating

      event :fetched do
        transition fetching: :pending
      end

      event :reject do
        transition pending: :rejected
      end

      event :revalidate do
        transition pending: :revalidating
      end

      event :cancel do
        transition any => :canceled
      end

      event :complete do
        transition pending: :merged
      end

      event :retry do
        transition %i(rejected canceled revalidating) => :pending
      end

      before_transition rejected: any do |pr|
        pr.rejection_reason = nil
      end

      before_transition %i(fetching rejected canceled) => :pending do |pr|
        pr.merge_requested_at = Time.now.utc
      end

      before_transition any => :pending do |pr|
        pr.revalidated_at = Time.now.utc
      end

      before_transition %i(pending) => :merged do |pr|
        Stack.increment_counter(:undeployed_commits_count, pr.stack_id)
      end
    end

    def self.schedule_merges
      Shipit::Stack.where(merge_queue_enabled: true).find_each(&:schedule_merges)
    end

    def self.extract_number(stack, number_or_url)
      case number_or_url
      when /\A#?(\d+)\z/
        $1.to_i
      when %r{\Ahttps://#{Regexp.escape(Shipit.github.domain)}/([^/]+)/([^/]+)/pull/(\d+)}
        return unless $1.downcase == stack.repo_owner.downcase
        return unless $2.downcase == stack.repo_name.downcase
        $3.to_i
      end
    end

    def self.request_merge!(stack, number, user, mode=Pipeline::MERGE_MODE_DEFAULT, with=[])
      if !stack.pipeline && (mode != Pipeline::MERGE_MODE_DEFAULT || with.present?)
        error_msg = "mode/with are not support for non-pipelined stacks (##{stack.id}/#{mode}/#{with})"
        raise ArgumentError, error_msg
      end

      merge_request = nil
      transaction do
        merge_request = request_merge(stack, number, user)
        # raise ArgumentError, "Merge Queue is enabled for stack ##{stack.id}." if stack.merge_queue_enabled?
        # errors << "Pull Request is neither waiting nor merged, this should be impossible."
        # if !merge_request.waiting? && !merge_request.merged?

        # 60 sec to do our thing
        stack.pipeline.sync_lock.lock do
          # Should change mode?
          if merge_request.mode != mode && mode != Pipeline::MERGE_MODE_DRY_RUN
            merge_request.update!(mode: mode)
          end

          # Validate
          errors = []
          final_with_merge_requests = []
          with.each do |with_stack, with_prs|
            with_prs.each do |with_number|
              with_merge_request = request_merge(with_stack, with_number, user)
              # Check that both root and with PRs belongs to the same pipeline
              if merge_request.stack.pipeline != with_merge_request.stack.pipeline
                errors << "Pull Request ('#{stack.repository.full_name}/pull/#{with_number}') is not mergable, it belongs to a different Pipeline."
              # Check that that with PR is not associated with other PRs
              elsif with_merge_request.with_parent_merge_request && with_merge_request.with_parent_merge_request.id != merge_request.id
                errors << "Pull Request ('#{stack.repository.full_name}/pull/#{with_number}') is not mergeable, already configured WITH a different Merge Request."
              else
                final_with_merge_requests << with_merge_request
              end
            end
          end

          # Allow remove with_* only if its closed
          removed_merged_requests = merge_request.with_merge_requests - final_with_merge_requests
          removed_merged_requests.each do |removed_merged_request|
            errors << "Pull Request ('#{stack.repository.full_name}/pull/#{with_number}') cannot be removed, it must be closed."
          end

          raise ArgumentError, "invalid reason merge request: #{errors.split("\n")}" if errors.any?
          return abort if Pipeline::MERGE_MODE_DRY_RUN == mode

          # Update new requirements
          merge_request.with_merge_requests = final_with_merge_requests

        end if stack.pipeline
      end

      merge_request.try(:schedule_refresh!)
      merge_request
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
      return reject!('ci_missing') if any_status_checks_missing?
      return reject!('ci_failing') if any_status_checks_failed?
      return reject!('requires_rebase') if stale?
      false
    end

    def merge!
      raise InvalidTransition unless pending?

      raise NotReady if not_mergeable_yet?

      Shipit.github.api.merge_pull_request(
        stack.github_repo_name,
        number,
        merge_message,
        sha: head.sha,
        commit_message: 'Merged by Shipit',
        merge_method: stack.merge_method,
      )
      begin
        if Shipit.github.api.pull_requests(stack.github_repo_name, base: branch).empty?
          Shipit.github.api.delete_branch(stack.github_repo_name, branch)
        end
      rescue Octokit::UnprocessableEntity
        # branch was already deleted somehow
      end
      complete!
      true
    rescue Octokit::MethodNotAllowed # merge conflict
      reject!('merge_conflict')
      false
    rescue Octokit::Conflict # shas didn't match, PR was updated.
      raise NotReady
    end

    def all_status_checks_passed?
      return false unless head
      StatusChecker.new(head, head.statuses_and_check_runs, stack.cached_deploy_spec).success?
    end

    def any_status_checks_failed?
      status = StatusChecker.new(head, head.statuses_and_check_runs, stack.cached_deploy_spec)
      status.failure? || status.error?
    end

    def any_status_checks_missing?
      StatusChecker.new(head, head.statuses_and_check_runs, stack.cached_deploy_spec).missing?
    end

    def waiting?
      WAITING_STATUSES.include?(merge_status)
    end

    def need_revalidation?
      timeout = stack.cached_deploy_spec&.revalidate_merge_requests_after
      return false unless timeout
      (revalidated_at + timeout).past?
    end

    def merge_conflict?
      mergeable == false
    end

    def not_mergeable_yet?
      mergeable.nil?
    end

    def schedule_refresh!
      RefreshMergeRequestJob.perform_later(self)
    end

    def closed?
      state == "closed"
    end

    def merged_upstream?
      closed? && merged_at
    end

    def refresh!
      update!(github_pull_request: Shipit.github.api.pull_request(stack.github_repo_name, number))
      head.refresh_statuses!
      fetched! if fetching?
      @comparison = nil
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
      self.merged_at = github_pull_request.merged_at
      self.base_ref = github_pull_request.base.ref
      self.base_commit = find_or_create_commit_from_github_by_sha!(github_pull_request.base.sha, detached: true)
    end

    def merge_message
      return title unless merge_requested_by
      "#{title}\n\n#{MERGE_REQUEST_FIELD}: #{merge_requested_by.login}\n"
    end

    def stale?
      return false unless base_commit
      spec = stack.cached_deploy_spec
      if max_branch_age = spec.max_divergence_age
        return true if Time.now.utc - head.committed_at > max_branch_age
      end
      if commit_count_limit = spec.max_divergence_commits
        return true if comparison.behind_by > commit_count_limit
      end
      false
    end

    def comparison
      @comparison ||= Shipit.github.api.compare(
        stack.github_repo_name,
        base_ref,
        head.sha,
      )
    end

    private

    def self.request_merge(stack, number, user)
      now = Time.now.utc
      merge_request = begin
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
      merge_request.update!(merge_requested_by: user.presence)
      merge_request.retry! if merge_request.rejected? || merge_request.canceled? || merge_request.revalidating?
      merge_request
    end


    def record_merge_status_change
      @merge_status_changed ||= saved_change_to_attribute?(:merge_status)
    end

    def emit_hooks
      return unless @merge_status_changed
      @merge_status_changed = nil
      Hook.emit('merge', stack, merge_request: self, status: merge_status, stack: stack)
    end

    def find_or_create_commit_from_github_by_sha!(sha, attributes)
      if commit = stack.commits.by_sha(sha)
        commit
      else
        github_commit = Shipit.github.api.commit(stack.github_repo_name, sha)
        stack.commits.create_from_github!(github_commit, attributes)
      end
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end
end
