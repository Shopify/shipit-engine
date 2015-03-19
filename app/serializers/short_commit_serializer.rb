class ShortCommitSerializer < ActiveModel::Serializer
  attributes :sha, :message
end
