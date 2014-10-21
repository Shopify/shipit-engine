class Commit < ActiveRecord::Base
  belongs_to :stack, touch: true
  has_many :deploys
  has_many :statuses, -> { order(created_at: :desc) }

  after_create  { broadcast_event('create') }
  after_destroy { broadcast_event('remove') }
  after_update  { broadcast_update }
  after_create { stack.update_undeployed_commits_count }

  belongs_to :author, class_name: "User"
  belongs_to :committer, class_name: "User"

  scope :newer_than, -> (commit) {
    id = commit.try(:id) || commit
    id ? where('id > ?', id) : all
  }

  scope :until, -> (commit) {
    id = commit.try(:id) || commit
    id ? where('id <= ?', id) : all
  }

  scope :reachable,  -> { where(detached: false) }

  def self.successful
    preload(:statuses).to_a.select(&:success?)
  end

  def self.detach!
    update_all(detached: true)
  end

  def self.by_sha!(sha)
    where('sha like ?', "#{sha}%").first!
  end

  def self.from_github(commit)
    new(
      sha: commit.sha,
      message: commit.commit.message,
      author: User.find_or_create_from_github(commit.author || commit.commit.author),
      committer: User.find_or_create_from_github(commit.committer || commit.commit.committer),
      committed_at: commit.commit.committer.date,
      authored_at: commit.commit.author.date,
      additions: commit.stats.additions,
      deletions: commit.stats.deletions,
    )
  end

  def refresh_statuses
    Shipit.github_api.statuses(stack.github_repo_name, sha).each do |status|
      statuses.replicate_from_github!(status)
    end
  end

  delegate :pending?, :success?, :error?, :failure?, to: :significant_status
  delegate :state, to: :significant_status # deprecated

  def last_statuses
    statuses.each_with_object({}) { |s, h| h[s.context] ||= s }.values.sort_by(&:context).presence || [UnknownStatus.new(self)]
  end

  def children
    self.class.where(stack_id: stack_id).newer_than(self)
  end

  def detach_children!
    children.detach!
  end

  def pull_request_url
    parsed && "https://github.com/#{stack.repo_owner}/#{stack.repo_name}/pull/#{pull_request_id}"
  end

  def pull_request_id
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
    @parsed ||= message.match(/\AMerge pull request #(?<pr_id>\d+) from [\w\-\_\/]+\n\n(?<pr_title>.*)/)
  end

  def schedule_continuous_delivery
    return unless state == 'success' && stack.continuous_deployment?
    return if deploy_in_progress? || newer_commit_deployed?
    stack.trigger_deploy(self, committer)
  end

  def broadcast_update
    if detached_changed? && detached?
      broadcast_event('remove')
    else
      broadcast_event('update')
    end
  end

  private

  def significant_status
    statuses = last_statuses
    return nil if statuses.empty?
    return statuses.first if statuses.all?(&:success?)
    non_success_statuses = statuses.reject(&:success?)
    non_success_statuses.reject(&:pending?).first || non_success_statuses.first || UnknownStatus.new(self)
  end

  def deploy_in_progress?
    stack.deploying?
  end

  def newer_commit_deployed?
    stack.last_deployed_commit.id > id
  end

  def broadcast_event(type)
    url = Rails.application.routes.url_helpers.stack_commit_path(stack, self)
    payload = {id: id, url: url}.to_json
    event = Pubsubstub::Event.new(payload, name: "commit.#{type}")
    Pubsubstub::RedisPubSub.publish("stack.#{stack_id}", event)
  end
end
