# frozen_string_literal: true
module Shipit
  class PullRequestAssignment < Record
    belongs_to :pull_request, required: true
    belongs_to :user, required: true

    validates :user_id, uniqueness: { scope: :pull_request_id }
  end
end
