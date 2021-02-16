# frozen_string_literal: true
module Shipit
  class DeploySerializer < TaskSerializer
    include GithubUrlHelper

    has_many :commits, serializer: CommitSerializer
    has_one :rollback_once_aborted_to, serializer: DeploySerializer

    attributes :compare_url, :rollback_url, :additions, :deletions

    def html_url
      stack_deploy_url(object.stack, object)
    end

    def compare_url
      github_commit_range_url(object.stack, object.since_commit, object.until_commit)
    end

    def rollback_url
      revert_stack_deploy_url(object.stack, object)
    end

    def type
      :deploy
    end
  end
end
