module Shipit
  class CommitSerializer < ShortCommitSerializer
    has_one :author
    has_one :committer

    attributes :additions, :deletions, :authored_at, :committed_at
  end
end
