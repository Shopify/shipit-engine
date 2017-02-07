module Shipit
  class PullRequestSerializer < ActiveModel::Serializer
    include ConditionalAttributes

    has_one :merge_requested_by
    has_one :head, serializer: ShortCommitSerializer

    attributes :id, :number, :title, :github_id, :additions, :deletions, :state, :merge_status, :mergeable,
               :merge_requested_at

    def include_rejection_reason?
      object.rejection_reason?
    end
  end
end
