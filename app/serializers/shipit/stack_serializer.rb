# frozen_string_literal: true
module Shipit
  class StackSerializer < Serializer
    attributes :id, :repo_owner, :repo_name, :environment, :html_url, :url, :tasks_url, :deploy_url,
      :merge_requests_url, :deploy_spec, :undeployed_commits_count, :is_locked, :lock_reason, :lock_author,
      :continuous_deployment, :created_at, :updated_at, :locked_since, :last_deployed_at, :branch,
      :merge_queue_enabled, :is_archived, :archived_since

    def url
      api_stack_url(object)
    end

    def html_url
      stack_url(object)
    end

    def tasks_url
      api_stack_tasks_url(object)
    end

    def merge_requests_url
      api_stack_merge_requests_url(object)
    end

    def is_archived
      object.archived?
    end

    def is_locked
      object.locked?
    end

    def lock_reason
      if object.locked?
        object.lock_reason
      else
        SKIP
      end
    end

    def lock_author
      if object.locked?
        Serializer.build(object.lock_author)
      else
        SKIP
      end
    end

    def locked_since
      if object.locked?
        object.locked_since
      else
        SKIP
      end
    end

    def deploy_spec
      object.cached_deploy_spec.cacheable.config
    end
  end
end
