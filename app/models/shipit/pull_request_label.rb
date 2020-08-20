# frozen_string_literal: true

module Shipit
  class PullRequestLabel < Record
    belongs_to :pull_request, required: true
    belongs_to :label, required: true

    validates :label_id, uniqueness: { scope: :pull_request_id }
  end
end
