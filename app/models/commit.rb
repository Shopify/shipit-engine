class Commit < ActiveRecord::Base
  belongs_to :stack
  has_many :deploys
  belongs_to :author, class_name: "User"
  belongs_to :committer, class_name: "User"

  def self.from_github(commit)
    new(
      :sha          => commit.sha,
      :message      => commit.commit.message,
      :author_id    => 0,
      :committer_id => 0
    )
  end

  def self.from_param(param)
    find_by_sha(sha)
  end

  def to_param
    sha
  end
end
