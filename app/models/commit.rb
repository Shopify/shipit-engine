class Commit < ActiveRecord::Base
  belongs_to :stack, touch: true
  has_many :deploys

  after_create  { broadcast_event('create') }
  after_destroy { broadcast_event('remove') }
  after_update  { broadcast_update('update') }
  after_update :schedule_continuous_delivery

  belongs_to :author, class_name: "User"
  belongs_to :committer, class_name: "User"

  scope :newer_than, -> (commit) {
    id = commit.try(:id) || commit
    id ? where('id > ?', id) : all
  }

  scope :reachable, -> { where(detached: false) }

  def self.detach!
    update_all(detached: true)
  end

  def self.from_github(commit, status)
    new(
      sha: commit.sha,
      state: status.try(:state) || 'unknown',
      target_url: fetch_target_url(status),
      message: commit.commit.message,
      author: User.find_or_create_from_github(commit.author || commit.commit.author),
      committer: User.find_or_create_from_github(commit.committer || commit.commit.committer),
      committed_at: commit.commit.committer.date,
      authored_at: commit.commit.author.date,
    )
  end

  def self.fetch_target_url(status)
    status && status.rels.try(:[], :target).try(:href)
  end

  def refresh_status
    if status = Shipit.github_api.statuses(stack.github_repo_name, sha).first
      update(state: status.try(:state) || 'unknown')
    end
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

  private

  def schedule_continuous_delivery
    return unless state == 'success' && stack.continuous_deployment?

    unless deploy_in_progress? || newer_commit_deployed?
      stack.trigger_deploy(self, committer)
    end
  end

  def deploy_in_progress?
    stack.deploys.running.count > 0
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

  def broadcast_update(type)
    if detached_changed? && detached?
      broadcast_event('remove')
    else
      broadcast_event('update')
    end
  end
end
