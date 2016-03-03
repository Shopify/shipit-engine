module Shipit
  class CreateOnGithubJob < BackgroundJob
    include BackgroundJob::Unique

    queue_as :default

    def perform(record)
      record.create_on_github!
    end
  end
end
