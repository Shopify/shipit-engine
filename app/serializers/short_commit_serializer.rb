class ShortCommitSerializer < ActiveModel::Serializer
  attributes :sha, :message

  def message
    object.pull_request? ? "#{object.pull_request_title} (##{object.pull_request_id})" : object.message
  end
end
