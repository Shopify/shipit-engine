# frozen_string_literal: true
module Shipit
  class PullRequestAssignment < Record
    belongs_to :merge_request, required: true
    belongs_to :user, required: true

    validates :user_id, uniqueness: { scope: :merge_request_id }
  end
end
