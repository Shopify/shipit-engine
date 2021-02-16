# frozen_string_literal: true
module Shipit
  class CommitSerializer < ShortCommitSerializer
    include GithubUrlHelper

    has_one :author, serializer: UserSerializer
    has_one :committer, serializer: UserSerializer

    attributes :additions, :deletions, :authored_at, :committed_at, :html_url, :pull_request, :status, :deployed

    aliases deployed?: :deployed

    def status
      object.status.state
    end

    def html_url
      github_commit_url(object)
    end

    def pull_request
      if object.pull_request?
        {
          number: object.pull_request_number,
          html_url: github_pull_request_url(object),
        }
      else
        SKIP
      end
    end
  end
end
