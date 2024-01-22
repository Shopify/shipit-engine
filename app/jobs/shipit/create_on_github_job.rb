# frozen_string_literal: true

module Shipit
  class CreateOnGithubJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default
    on_duplicate :drop

    # We observe that some objects regularly take longer than the default 10 seconds to create, e.g. deployments
    self.timeout = 40
    self.lock_timeout = 20

    def perform(record)
      record.reload.create_on_github!
    end
  end
end
