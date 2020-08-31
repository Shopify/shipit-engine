# frozen_string_literal: true

module Shipit
  class PullRequestSerializer < ActiveModel::Serializer
    include GithubUrlHelper
    include ConditionalAttributes

    has_one :user
    has_one :head, serializer: ShortCommitSerializer
    has_many :assignees, serializer: UserSerializer

    attributes :id, :number, :title, :github_id, :additions, :deletions, :state, :html_url

    def html_url
      github_pull_request_url(object) if object.stack.present?
    end
  end
end
