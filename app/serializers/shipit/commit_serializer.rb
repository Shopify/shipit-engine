# frozen_string_literal: true

module Shipit
  class CommitSerializer < ShortCommitSerializer
    include GithubUrlHelper
    include ConditionalAttributes

    has_one :author
    has_one :committer

    attributes :additions, :deletions, :authored_at, :committed_at, :html_url, :pull_request, :status, :deployed

    def deployed
      object.deployed?
    end

    def status
      object.status.state
    end

    def html_url
      github_commit_url(object)
    end

    def pull_request
      {
        number: object.pull_request_number,
        html_url: github_pull_request_url(object)
      }
    end

    def include_pull_request?
      object.pull_request?
    end
  end
end
