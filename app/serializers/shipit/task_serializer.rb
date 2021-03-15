# frozen_string_literal: true
module Shipit
  class TaskSerializer < ActiveModel::Serializer
    include ConditionalAttributes

    has_one :author
    has_one :revision, serializer: ShortCommitSerializer

    attributes(:id, :url, :html_url, :output_url, :type, :status, :action, :title, :description, :started_at, :ended_at, :updated_at, :created_at, :env, :ignored_safeties, :max_retries, :retry_attempt)

    def revision
      object.until_commit
    end

    def url
      api_stack_task_url(object.stack, object)
    end

    def html_url
      stack_task_url(object.stack, object)
    end

    def output_url
      api_stack_task_output_url(object.stack, object)
    end

    def type
      :task
    end

    def action
      object.definition&.action
    end

    def include_action?
      type == :task
    end

    def description
      object.definition&.action
    end

    def include_description?
      type == :task
    end
  end
end
