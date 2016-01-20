module Shipit
  class StackSerializer < ActiveModel::Serializer
    include ConditionalAttributes

    has_one :lock_author
    attributes :id, :repo_owner, :repo_name, :environment, :html_url, :url, :tasks_url, :deploy_spec,
               :undeployed_commits_count, :is_locked, :lock_reason, :continuous_deployment, :created_at, :updated_at

    def url
      api_stack_url(object)
    end

    def html_url
      stack_url(object)
    end

    def tasks_url
      api_stack_tasks_url(object)
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

    def deploy_spec
      object.cached_deploy_spec
    end
  end
end
