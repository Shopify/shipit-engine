# frozen_string_literal: true
module Shipit
  class CreateReleaseStatusesJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default
    on_duplicate :drop

    def perform(commit)
      commit.release_statuses.to_be_created.each(&:create_status_on_github!)
    end
  end
end
