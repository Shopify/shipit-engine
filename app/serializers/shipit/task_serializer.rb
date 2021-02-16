# frozen_string_literal: true
module Shipit
  class TaskSerializer < Serializer
    has_one :author, serializer: UserSerializer
    has_one :until_commit, serializer: ShortCommitSerializer, name: :revision

    attributes(:id, :url, :html_url, :output_url, :type, :status, :action, :title, :description, :started_at, :ended_at, :updated_at, :created_at, :env, :ignored_safeties, :max_retries, :retry_attempt)

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
      if type == :task
        object.definition&.action
      else
        SKIP
      end
    end

    def description
      if type == :task
        object.definition&.action
      else
        SKIP
      end
    end
  end
end
