module Shipit
  class Commit < ActiveRecord::Base
    AmbiguousRevision = Class.new(StandardError)

    belongs_to :stack, touch: true
    has_many :deploys
    has_many :statuses, -> { order(created_at: :desc) }

    after_commit { broadcast_update }
    after_create { stack.update_undeployed_commits_count }

    after_commit :schedule_refresh_statuses!, :schedule_fetch_stats!, on: :create

    after_touch :touch_stack

    belongs_to :author, class_name: 'User', inverse_of: :authored_commits
    belongs_to :committer, class_name: 'User', inverse_of: :commits

    scope :reachable, -> { where(detached: false) }

    delegate :broadcast_update, :github_repo_name, to: :stack

    def self.newer_than(commit)
      return all unless commit
      where('id > ?', commit.is_a?(Commit) ? commit.id : commit)
    end

    def self.until(commit)
      return all unless commit
      where('id <= ?', commit.is_a?(Commit) ? commit.id : commit)
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
      new(
        sha: commit.sha,
        message: commit.commit.message,
        author: User.find_or_create_from_github(commit.author || commit.commit.author),
        committer: User.find_or_create_from_github(commit.committer || commit.commit.committer),
        committed_at: commit.commit.committer.date,
        authored_at: commit.commit.author.date,
        additions: commit.stats.try!(:additions),
        deletions: commit.stats.try!(:deletions),
      )
    end

    def reload(*)
      @last_statuses = nil
      super
    end

    def self.create_from_github!(commit)
      from_github(commit).save!
    end

    def schedule_refresh_statuses!
      RefreshStatusesJob.perform_later(commit_id: id)
    end

    def refresh_statuses!
      Shipit.github_api.statuses(github_repo_name, sha).each do |status|
        statuses.replicate_from_github!(status)
      end
    end

    def add_status(status_attributes)
      previous_status = significant_status
      statuses.create!(status_attributes)
      reload # to get the statuses into the right order (since sorted :desc)
      new_status = significant_status

      payload = {commit: self, stack: stack, status: new_status.state}
      Hook.emit(:commit_status, stack, payload.merge(commit_status: new_status)) if previous_status != new_status
      if simple_state(previous_status) != simple_state(new_status) && !new_status.pending?
        Hook.emit(:deployable_status, stack, payload.merge(deployable_status: new_status))
      end
      new_status
    end

    def checks
      @checks ||= CommitChecks.new(self)
    end

    delegate :pending?, :success?, :error?, :failure?, :state, to: :status

    def deployable?
      success? || stack.ignore_ci?
    end

    def children
      self.class.where(stack_id: stack_id).newer_than(self)
    end

    def detach_children!
      children.detach!
    end

    def pull_request_url
      parsed && Shipit.github_url("/#{stack.repo_owner}/#{stack.repo_name}/pull/#{pull_request_number}")
    end

    def pull_request_number
      parsed && parsed['pr_id'].to_i
    end

    def pull_request_title
      parsed && parsed['pr_title']
    end

    def pull_request?
      !!parsed
    end

    def short_sha
      sha[0..9]
    end

    def parsed
      @parsed ||= message.match(/\AMerge pull request #(?<pr_id>\d+) from [\w\-.\/]+\n\n(?<pr_title>.*)/)
    end

    def schedule_continuous_delivery
      return unless state == 'success' && stack.continuous_deployment? && stack.deployable?
      ContinuousDeliveryJob.perform_later(stack)
    end

    def github_commit
      @github_commit ||= Shipit.github_api.commit(github_repo_name, sha)
    end

    def schedule_fetch_stats!
      FetchCommitStatsJob.perform_later(self)
    end

    def fetch_stats!
      update!(
        additions: github_commit.stats.try!(:additions),
        deletions: github_commit.stats.try!(:deletions),
      )
    end

    def visible_statuses
      stack.filter_visible_statuses(last_statuses).presence || [UnknownStatus.new(self)]
    end

    def meaningful_statuses
      stack.filter_meaningful_statuses(last_statuses).presence || [UnknownStatus.new(self)]
    end

    def last_statuses
      @last_statuses ||= statuses.to_a.uniq(&:context).sort_by(&:context).presence || [UnknownStatus.new(self)]
    end

    def status
      visibles = visible_statuses
      status = visibles.size > 1 ? StatusGroup.new(significant_status, visibles) : visibles.first
      missing_statuses.empty? ? status : MissingStatus.new(status, missing_statuses)
    end

    def significant_status
      statuses = meaningful_statuses
      return UnknownStatus.new(self) if statuses.empty?
      return statuses.first if statuses.all?(&:success?)
      non_success_statuses = statuses.reject(&:success?)
      non_success_statuses.reject(&:pending?).first || non_success_statuses.first || UnknownStatus.new(self)
    end

    def deployed?
      stack.last_deployed_commit.id >= id
    end

    private

    def missing_statuses
      stack.required_statuses - last_statuses.map(&:context)
    end

    def touch_stack
      stack.touch
    end

    def simple_state(status)
      status.state == 'error' ? 'failure' : status.state
    end
  end
end
