class Commit < ActiveRecord::Base
  belongs_to :stack, touch: true
  has_many :deploys
  belongs_to :author, class_name: "User"
  belongs_to :committer, class_name: "User"

  def self.from_github(commit, state = nil)
    state ||= 'unknown'
    p commit.sha
    new(
      :sha       => commit.sha,
      :state     => state,
      :message   => commit.commit.message,
      :author    => User.find_or_create_from_github(commit.author || commit.commit.author),
      :committer => User.find_or_create_from_github(commit.committer || commit.commit.committer),
    )
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
