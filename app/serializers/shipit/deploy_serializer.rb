# frozen_string_literal: true

module Shipit
  class DeploySerializer < TaskSerializer
    include GithubUrlHelper

    has_many :commits

    attributes :compare_url, :rollback_url, :additions, :deletions, :rollback_once_aborted_to,
               :commits_count, :commits_truncated

    # Capped only when the serialization context asks for it, which the API controllers do and hook
    # payloads do not. See Shipit::Api::BaseController#default_serializer_options.
    def commits
      @commits ||= commits_limit ? object.commits.limit(commits_limit) : object.commits
    end

    def commits_count
      @commits_count ||= object.commits.count
    end

    def commits_truncated
      !commits_limit.nil? && commits_count > commits_limit
    end

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

    def rollback_once_aborted_to
      return nil unless object.rollback_once_aborted_to

      DeploySerializer.new(object.rollback_once_aborted_to)
    end

    private

    def commits_limit
      context && context[:commits_limit]
    end
  end
end
