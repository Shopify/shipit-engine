class StackSerializer < ActiveModel::Serializer
  include ConditionalAttributes

  attributes :id, :repo_owner, :repo_name, :environment, :html_url, :url, :is_locked, :lock_reason

  def url
    api_stacks_url(object)
  end

  def html_url
    stacks_url(object)
  end

  def is_locked
    object.locked?
  end

  def include_lock_reason?
    object.locked?
  end
end
