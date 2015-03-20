class TaskSerializer < ActiveModel::Serializer
  include ConditionalAttributes

  has_one :user

  attributes :id, :revision, :url, :html_url, :output_url, :type, :status, :updated_at, :created_at

  def revision
    ShortCommitSerializer.new(object.until_commit).as_json
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
end
