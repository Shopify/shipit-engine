module Shipit
  class DeploySerializer < TaskSerializer
    include GithubUrlHelper

    has_many :commits

    attributes :compare_url, :additions, :deletions

    def html_url
      stack_deploy_url(object.stack, object)
    end

    def compare_url
      github_commit_range_url(object.stack, object.since_commit, object.until_commit)
    end

    def type
      :deploy
    end
  end
end
