# frozen_string_literal: true
module Shipit
  class MergeRequestSerializer < Serializer
    include GithubUrlHelper

    has_one :merge_requested_by, serializer: UserSerializer
    has_one :head, serializer: ShortCommitSerializer

    attributes :id, :number, :title, :github_id, :additions, :deletions, :state, :merge_status, :mergeable,
               :merge_requested_at, :rejection_reason, :html_url, :branch, :base_ref

    def html_url
      github_pull_request_url(object)
    end

    def rejection_reason
      if object.rejection_reason?
        object.rejection_reason
      else
        SKIP
      end
    end
  end
end
