# frozen_string_literal: true
require 'fileutils'

module Shipit
  class Deploy < Task
    CONFIRMATIONS_REQUIRED = 5

    state_machine :status do
      after_transition to: :success, do: :schedule_continuous_delivery
      after_transition to: :success, do: :schedule_merges
      after_transition to: :success, do: :update_undeployed_commits_count
      after_transition to: :aborted, do: :trigger_revert_if_required
      after_transition any => any, do: :update_release_status
      after_transition any => any, do: :update_commit_deployments
      after_transition any => any, do: :update_last_deploy_time
      after_transition any => any, do: :check_for_retry
    end

    belongs_to :until_commit, class_name: 'Commit', required: true, inverse_of: :deploys
    belongs_to :since_commit, class_name: 'Commit', required: true, inverse_of: :deploys
    has_many :commit_deployments, dependent: :destroy, inverse_of: :task, foreign_key: :task_id do
      GITHUB_STATUSES = {
        'pending' => 'pending',
        'running' => 'in_progress',
        'failed' => 'failure',
        'timedout' => 'failure',
        'success' => 'success',
        'faulty' => 'error',
        'error' => 'error',
        'aborted' => 'error',
      }.freeze

      def append_status(task_status)
        if github_status = GITHUB_STATUSES[task_status]
          # Deployments and statuses are created async, we reload the association to ensure we update all instances
          reload.each do |deployment|
            Rails.logger.info(
              "Creating #{github_status} deploy status for deployment #{deployment.id}. "\
              "Commit: #{deployment.sha}, Github id: #{deployment.github_id}, "\
              "Repo: #{deployment.stack.repo_name}, Environment: #{deployment.stack.environment}, "\
              "API Url: #{deployment.api_url}.",
            )
            deployment.statuses.create!(status: github_status)
          end
        else
          each do |deployment|
            Rails.logger.warn(
              "No GitHub status for task status #{task_status}. "\
              "Commit: #{deployment.sha}, Github id: #{deployment.github_id}, "\
              "Repo: #{deployment.stack.repo_name}, Environment: #{deployment.stack.environment}, "\
              "API Url: #{deployment.api_url}.",
            )
          end
        end
      end
    end

    before_create :denormalize_commit_stats
    after_create :create_commit_deployments
    after_create :update_release_status
    after_commit :broadcast_update
    after_commit :update_latest_deployed_ref, on: :update

    delegate :broadcast_update, :filter_deploy_envs, to: :stack

    def set_metrics
      super()
      pipeline = stack.pipeline.id.to_s
      stack_name = stack.repository.full_name
      labels = {pipeline: pipeline, stack: stack_name}
      value = 0
      value = retry_attempt if status.in?(UNSUCCESSFUL_STATUSES)
      ApplicationMetrics.set_gauge(:cd_sequential_failures, labels, value)
      ApplicationMetrics.increment_gauge(:cd_sequential_failures_test, labels)
    rescue Exception => e
      puts "Shipit::Deploy#set_metrics - Error: #{e.message}"
    end

    def self.newer_than(deploy)
      return all unless deploy
      where('id > ?', deploy.try(:id) || deploy)
    end

    def self.older_than(deploy)
      return all unless deploy
      where('id < ?', deploy.try(:id) || deploy)
    end

    def self.since(deploy)
      return all unless deploy
      where('id >= ?', deploy.try(:id) || deploy)
    end

    def self.until(deploy)
      return all unless deploy
      where('id <= ?', deploy.try(:id) || deploy)
    end

    def build_rollback(user = nil, env: nil, force: false)
      Rollback.new(
        user_id: user&.id,
        stack_id: stack_id,
        parent_id: id,
        since_commit: stack.last_deployed_commit,
        until_commit: until_commit,
        env: env&.to_h || {},
        allow_concurrency: force,
        ignored_safeties: force,
        max_retries: stack.cached_deploy_spec.retries_on_rollback_timeout,
      )
    end

    # Rolls the stack back to this deploy
    def trigger_rollback(user = AnonymousUser.new, env: nil, force: false)
      rollback = build_rollback(user, env: env, force: force)
      rollback.save!
      rollback.enqueue

      lock_reason = "A rollback for #{rollback.since_commit.sha} has been triggered. " \
        "Please make sure the reason for the rollback has been addressed before deploying again."
      stack.update!(lock_reason: lock_reason, lock_author_id: user.id)

      rollback
    end

    # Rolls the stack back to the most recent **previous** successful deploy
    def trigger_revert(force: false, rollback_to: nil)
      previous_successful_commit = rollback_to&.until_commit || commit_to_rollback_to

      rollback = Rollback.create!(
        user_id: user_id,
        stack_id: stack_id,
        parent_id: id,
        since_commit: until_commit,
        until_commit: previous_successful_commit,
        allow_concurrency: force,
      )

      rollback.enqueue
      lock_reason = "A rollback for #{until_commit.sha} has been triggered. " \
        "Please make sure the reason for the rollback has been addressed before deploying again."
      stack.update!(lock_reason: lock_reason, lock_author_id: user_id)
      rollback
    end

    def title
      I18n.t("#{self.class.name.demodulize.underscore.pluralize}.description", sha: until_commit.short_sha)
    end

    def rollback?
      false
    end

    def commit_range
      [since_commit, until_commit]
    end

    delegate :supports_rollback?, to: :stack

    def rollbackable?
      success? && supports_rollback? && !currently_deployed?
    end

    def currently_deployed?
      until_commit_id == stack.last_deployed_commit.id
    end

    def commits
      return Commit.none unless stack

      @commits ||= stack.commits.reachable.newer_than(since_commit_id).until(until_commit_id).order(id: :desc)
    end

    def commits_since
      return Commit.none unless stack

      @commits_since ||= stack.commits.reachable.newer_than(until_commit_id).order(id: :desc)
    end

    def since_commit_id
      super || default_since_commit_id
    end

    def variables
      stack.deploy_variables
    end

    def reject!
      return if failed? || aborted?
      transaction do
        flap! unless flapping?
        update!(confirmations: [confirmations - 1, -1].min)
        failure! if confirmed?
      end
    end

    def accept!
      return if success?
      transaction do
        flap! unless flapping?
        update!(confirmations: [confirmations + 1, 1].max)
        complete! if confirmed?
      end
    end

    def confirmed?
      confirmations.abs >= CONFIRMATIONS_REQUIRED
    end

    delegate :last_release_status, to: :until_commit
    def append_release_status(state, description, user: self.user)
      status = until_commit.create_release_status!(
        state,
        user: user.presence,
        target_url: permalink,
        description: description,
      )
      status
    rescue Exception => error
      Rails.logger.error "Can't append release status. message: #{error.message}"
    end

    def set_deploy_comment_on_pr(state, description, link)
      puts "Shipit::Deploy#set_deploy_comment_on_pr; description: #{description}; link: #{link}"
      mrs = related_merge_requests
      mrs.each do |mr|
        msg = <<~MSG
          #{description}:
          #{link}
        MSG
        Shipit.github.api.add_comment(mr.stack.repository.full_name, mr.number, msg)
      end
    rescue Exception => error
      Rails.logger.error "Can't set_deploy_comment_on_pr. message: #{error.message}"
    end

    def permalink
      Shipit::Engine.routes.url_helpers.stack_deploy_url(stack, self)
    end

    def report_complete!
      if stack.release_status? && stack.release_status_delay.positive?
        enter_validation!
      else
        super
      end
    end

    def report_healthy!(user: self.user, description: "@#{user.login} signaled this release as healthy.")
      transaction do
        complete! if can_complete?
        append_release_status(
          'success',
          description,
          user: user,
        )
      end
    end

    def report_faulty!(user: self.user, description: "@#{user.login} signaled this release as faulty.")
      transaction do
        mark_faulty! if can_mark_faulty?
        append_release_status(
          'failure',
          description,
          user: user,
        )
      end
    end

    def update_commit_deployments
      commit_deployments.append_status(status)
    end

    def related_merge_requests
      mrs = []
      commits_sha = related_commits_sha
      predictive_branches = Shipit::PredictiveBranch.where(until_commit_sha: commits_sha)
      predictive_branches.each do |p_branch|
        p_branch.predictive_merge_requests.each do |pmr|
          mrs << pmr.merge_request
        end
      end
      mrs
    end

    def related_commits_sha
      commits_sha = []
      Dir.mktmpdir do |dir|
        stack_command = Shipit::PredictiveBuildCommands.new(nil, stack, File.join(dir, stack.repo_name))
        stack_command.git_clone(chdir: dir).run!
        commits_sha = stack_command.git_get_commits_in_range(since_commit.sha, until_commit.sha).run!
        commits_sha = commits_sha.split(/[\r\n]+/)
      end
      commits_sha
    end

    private

    def create_commit_deployments
      # Create one deployment for the head of the batch
      commit_deployments.create!(sha: until_commit.sha)

      # Create one for each pull request in the batch, to give feedback on the PR timeline
      commits.select(&:pull_request?).each do |commit|
        next if commit.pull_request_head_sha.blank? # This attribute was not always populated
        commit_deployments.create!(sha: commit.pull_request_head_sha)
      end

      # Immediately update to publish the status to the commit deployments
      update_commit_deployments
    end

    def update_release_status
      return unless stack.release_status?
      description = nil
      case status
      when 'pending'
        description = "A deploy was triggered on #{stack.environment}"
          append_release_status('pending', description)
      when 'failed', 'error', 'timedout'
        description = "The deploy on #{stack.environment} did not succeed (#{status})"
        append_release_status('error', description)
      when 'aborted', 'aborting'
        description = "The deploy on #{stack.environment} was canceled"
        append_release_status('failure', description)
      when 'validating'
        if stack.release_status_delay.positive?
          description = "The deploy on #{stack.environment} succeeded"
          append_release_status('pending', description)
          MarkDeployHealthyJob.set(wait: stack.release_status_delay).perform_later(self)
        end
      when 'success'
        if stack.release_status_delay.zero?
          description = "The deploy on #{stack.environment} succeeded"
          append_release_status('success', description)
        end
      end
      set_deploy_comment_on_pr(status, description, permalink) if description
    end

    def check_for_retry
      begin
        retry_if_necessary if status.in?(['failed', 'error', 'timedout'])
      rescue Exception => error
        puts "Shipit::Deploy#retry_if_necessary failed to check; status: #{status}; message: #{error.message}"
      end
    end

    def trigger_revert_if_required
      return unless rollback_once_aborted?
      return unless supports_rollback?
      trigger_revert(rollback_to: rollback_once_aborted_to)
    end

    def default_since_commit_id
      return unless stack
      @default_since_commit_id ||= stack.last_completed_deploy&.until_commit_id
    end

    def denormalize_commit_stats
      self.additions = commits.map(&:additions).compact.sum
      self.deletions = commits.map(&:deletions).compact.sum
    end

    def schedule_merges
      stack.schedule_merges
    end

    def schedule_continuous_delivery
      return unless stack.continuous_deployment?
      ContinuousDeliveryJob.perform_later(stack)
    end

    def update_undeployed_commits_count
      stack.update_undeployed_commits_count(until_commit)
    end

    def update_last_deploy_time
      stack.update(last_deployed_at: ended_at)
    end

    def update_latest_deployed_ref
      return unless previous_changes.include?(:status)
      stack.update_latest_deployed_ref if previous_changes[:status].last == 'success'
    end
  end
end
