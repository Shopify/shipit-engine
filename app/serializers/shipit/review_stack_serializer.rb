# frozen_string_literal: true

module Shipit
  class ReviewStackSerializer < Shipit::StackSerializer
    has_one :review_request
  end
end
