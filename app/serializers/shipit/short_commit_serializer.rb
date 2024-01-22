# frozen_string_literal: true

module Shipit
  class ShortCommitSerializer < ActiveModel::Serializer
    attributes :sha, :message

    def message
      object.pull_request? ? object.pull_request_title : object.message
    end
  end
end
