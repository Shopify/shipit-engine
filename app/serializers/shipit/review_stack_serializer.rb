# frozen_string_literal: true

module Shipit
  class ReviewStackSerializer < Shipit::StackSerializer
    has_one :pull_request
  end
end
