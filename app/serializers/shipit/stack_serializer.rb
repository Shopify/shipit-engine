# typed: false
module Shipit
  class StackSerializer < ActiveModel::Serializer
    include ConditionalAttributes

    has_one :lock_author
    attributes :id, :repo_owner, :repo_name, :environment, :html_url, :url, :tasks_url, :deploy_url, :pull_requests_url,
               :deploy_spec, :undeployed_commits_count, :is_locked, :lock_reason, :continuous_deployment, :created_at,
               :updated_at, :locked_since, :last_deployed_at, :branch, :merge_queue_enabled, :is_archived,
               :archived_since

    def url
      api_stack_url(object)
    end

    def html_url
      stack_url(object)
    end

    def tasks_url
      api_stack_tasks_url(object)
    end

    def pull_requests_url
      api_stack_pull_requests_url(object)
    end

    def is_locked
      object.locked?
    end

    def include_lock_reason?
      object.locked?
    end

    def include_lock_author?
      object.locked?
    end

    def include_locked_since?
      object.locked?
    end

    def is_archived
      object.archived?
    end

    def deploy_spec
      object.cached_deploy_spec.cacheable.config
    end
  end
end
