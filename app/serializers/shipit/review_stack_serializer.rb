# frozen_string_literal: true

module Shipit
  class ReviewStackSerializer < StackSerializer
    has_one :pull_request, serializer: PullRequestSerializer
  end
end
