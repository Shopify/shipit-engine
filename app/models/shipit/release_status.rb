# frozen_string_literal: true

module Shipit
  class ReleaseStatus < Record
    MAX_DESCRIPTION_LENGTH = 140
    include DeferredTouch

    belongs_to :stack
    belongs_to :commit
    belongs_to :user, optional: true

    deferred_touch stack: :updated_at, commit: :updated_at
    after_commit :schedule_create_release_statuses, on: :create

    scope :to_be_created, -> { where(github_id: nil).order(id: :asc) }

    STATES = %w(pending success failure error).freeze
    validates :state, presence: true, inclusion: { in: STATES }

    def create_status_on_github!
      return true if github_id?

      update!(github_id: create_status_on_github.id)
    end

    private

    def create_status_on_github
      stack.github_api.create_status(
        stack.github_repo_name,
        commit.sha,
        state,
        context: stack.release_status_context,
        target_url:,
        description: description&.truncate(MAX_DESCRIPTION_LENGTH),
      )
    end

    def schedule_create_release_statuses
      CreateReleaseStatusesJob.perform_later(commit)
    end
  end
end
