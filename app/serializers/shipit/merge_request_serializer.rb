# frozen_string_literal: true

module Shipit
  class MergeRequestSerializer < ActiveModel::Serializer
    include GithubUrlHelper
    include ConditionalAttributes

    has_one :merge_requested_by
    has_one :head, serializer: ShortCommitSerializer

    attributes :id, :number, :title, :github_id, :additions, :deletions, :state, :merge_status, :mergeable,
      :merge_requested_at, :rejection_reason, :html_url, :branch, :base_ref

    def html_url
      github_pull_request_url(object)
    end

    def include_rejection_reason?
      object.rejection_reason?
    end
  end
end
