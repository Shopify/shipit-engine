class CommitSerializer < ActiveModel::Serializer
  has_one :author
  has_one :committer

  attributes :sha, :message, :additions, :deletions, :authored_at, :committed_at
end
