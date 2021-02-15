# frozen_string_literal: true

module Shipit
  class PullRequestSerializer < Serializer
    include GithubUrlHelper

    has_one :user, serializer: UserSerializer
    has_one :head, serializer: ShortCommitSerializer
    has_many :assignees, serializer: UserSerializer

    attributes :id, :number, :title, :github_id, :additions, :deletions, :state, :html_url

    def html_url
      if object.stack.present?
        github_pull_request_url(object)
      else
        SKIP
      end
    end
  end
end
