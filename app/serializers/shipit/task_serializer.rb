module Shipit
  class TaskSerializer < ActiveModel::Serializer
    include ConditionalAttributes

    has_one :author
    has_one :revision, serializer: ShortCommitSerializer

    attributes(*%i(
      id
      url
      html_url
      output_url
      type
      status
      action
      description
      started_at
      ended_at
      updated_at
      created_at
      env
    ))

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
      object.definition.try!(:action)
    end

    def include_action?
      type == :task
    end

    def description
      object.definition.try!(:action)
    end

    def include_description?
      type == :task
    end
  end
end
