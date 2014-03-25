class Commit < ActiveRecord::Base
  belongs_to :stack, touch: true
  has_many :deploys

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
end
